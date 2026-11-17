//// Every way `coverage.start` and `coverage.finish` can fail, triggered for
//// real in a child node. Broken modules are built inside the child; a stub
//// `cover` stands in for the failures `cover` itself only shows when it is
//// broken.

import dream_test/coverage.{
  type CoverageError, type CoverageSession, AlreadyInstrumented, BadBeamFile,
  CoverDidNotStart, CoverStartFailed, EmbeddedMode, EncryptedDebugInfo,
  InstrumentedLoadFailed, ModuleNotAnalysed, ModuleNotBuilt,
  ModuleNotInstrumented, ModuleNotLoaded, NoDebugInfo, NotInstrumented,
  OnLoadFailed, UnknownAnalysisError, UnknownInstrumentError,
}
import dream_test/coverage_child_support.{
  add_damaged_beam, add_source, child_project, compile_source, measure,
  run_in_child, run_in_embedded_child, stop_cover, stub_cover, without_raw,
}
import dream_test/file.{write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}

fn fixture_config() {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
}

fn project_config() {
  coverage.new() |> coverage.no_lcov()
}

fn start_error(
  result: Result(CoverageSession, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected start to fail")
  }
}

fn finish_error(
  result: Result(a, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected finish to fail")
  }
}

/// In a child: create a project with one module, compiled with `kind` debug
/// information, and start coverage on it.
fn start_on_compiled_module(file: String, text: String, kind: String) {
  let _ = child_project("compiled")
  add_source(file, text)
  compile_source(file, kind)
  case coverage.start(project_config()) {
    Error(error) -> Ok(without_raw(error))
    Ok(_) -> Error("expected start to fail")
  }
}

fn ffi_path() {
  "test/coverage_fixtures/coverage_fixture_ffi.erl"
}

pub fn tests() {
  describe("coverage failures in a child node", [
    group("cover does not start", [
      it("returns CoverDidNotStart when cover returns an error", fn() {
        run_in_child(fn() {
          stub_cover("start_returns_error")
          fixture_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(Ok(Ok(CoverStartFailed(CoverDidNotStart, "boom"))))
        |> or_fail_with("expected CoverDidNotStart with boom")
      }),
      it("returns CoverDidNotStart when cover raises", fn() {
        run_in_child(fn() {
          stub_cover("start_raises")
          fixture_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(Ok(Ok(CoverStartFailed(CoverDidNotStart, "{error,boom}"))))
        |> or_fail_with("expected CoverDidNotStart with {error,boom}")
      }),
    ]),

    group("module does not load", [
      it("returns ModuleNotBuilt for a source file with no .beam", fn() {
        run_in_child(fn() {
          let _ = child_project("not_built")
          add_source("ghost.erl", "-module(ghost).\n")
          project_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded(
              "ghost",
              "src/ghost.erl",
              ModuleNotBuilt,
              "nofile",
            )),
          ),
        )
        |> or_fail_with("expected ModuleNotBuilt")
      }),
      it("names modules from a dev source directory", fn() {
        run_in_child(fn() {
          let _ = child_project("dev_root")
          let _ = write("dev/tool.erl", "-module(tool).\n")
          coverage.new()
          |> coverage.source_directory("dev")
          |> coverage.no_lcov()
          |> coverage.start()
          |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded("tool", "dev/tool.erl", ModuleNotBuilt, "nofile")),
          ),
        )
        |> or_fail_with("expected the dev module to be looked up as tool")
      }),
      it("returns OnLoadFailed when the on_load function fails", fn() {
        run_in_child(fn() {
          let _ = child_project("on_load")
          add_source(
            "failing_on_load.erl",
            "-module(failing_on_load).\n-on_load(init/0).\ninit() -> not_ok.\n",
          )
          compile_source("failing_on_load.erl", "debug_info")
          project_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded(
              "failing_on_load",
              "src/failing_on_load.erl",
              OnLoadFailed,
              "on_load_failure",
            )),
          ),
        )
        |> or_fail_with("expected OnLoadFailed")
      }),
      it("returns BadBeamFile for a damaged .beam", fn() {
        run_in_child(fn() {
          let _ = child_project("damaged")
          add_source("damaged.erl", "-module(damaged).\n")
          add_damaged_beam("damaged")
          project_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded(
              "damaged",
              "src/damaged.erl",
              BadBeamFile,
              "badfile",
            )),
          ),
        )
        |> or_fail_with("expected BadBeamFile")
      }),
      it("returns EmbeddedMode when the BEAM runs in embedded mode", fn() {
        run_in_embedded_child(fn() {
          let _ = child_project("embedded")
          add_source("ghost.erl", "-module(ghost).\n")
          project_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded(
              "ghost",
              "src/ghost.erl",
              EmbeddedMode,
              "embedded",
            )),
          ),
        )
        |> or_fail_with("expected EmbeddedMode")
      }),
    ]),

    group("module is not instrumented", [
      it("returns NoDebugInfo for a .beam without debug information", fn() {
        run_in_child(fn() {
          start_on_compiled_module(
            "plain.erl",
            "-module(plain).\n-export([f/0]).\nf() -> 1.\n",
            "no_debug_info",
          )
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotInstrumented("plain", "src/plain.erl", NoDebugInfo, "")),
          ),
        )
        |> or_fail_with("expected NoDebugInfo")
      }),
      it(
        "returns NoDebugInfo when the debug information backend is missing",
        fn() {
          run_in_child(fn() {
            start_on_compiled_module(
              "backend.erl",
              "-module(backend).\n-export([f/0]).\nf() -> 1.\n",
              "missing_debug_info_backend",
            )
          })
          |> should
          |> be_equal(
            Ok(
              Ok(ModuleNotInstrumented(
                "backend",
                "src/backend.erl",
                NoDebugInfo,
                "",
              )),
            ),
          )
          |> or_fail_with("expected NoDebugInfo for a missing backend")
        },
      ),
      it("returns EncryptedDebugInfo for encrypted debug information", fn() {
        run_in_child(fn() {
          start_on_compiled_module(
            "secret.erl",
            "-module(secret).\n-export([f/0]).\nf() -> 1.\n",
            "encrypted_debug_info",
          )
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotInstrumented(
              "secret",
              "src/secret.erl",
              EncryptedDebugInfo,
              "",
            )),
          ),
        )
        |> or_fail_with("expected EncryptedDebugInfo")
      }),
      it(
        "returns AlreadyInstrumented when another tool instrumented the module",
        fn() {
          run_in_child(fn() {
            let _ = child_project("already")
            add_source(
              "a_loader.erl",
              "-module(a_loader).\n-on_load(init/0).\n"
                <> "init() -> case persistent_term:get(a_loader, false) of\n"
                <> "  false -> persistent_term:put(a_loader, true), {ok, z_target} = cover:compile_module(\"src/z_target.erl\"), ok;\n"
                <> "  true -> ok\nend.\n",
            )
            add_source(
              "z_target.erl",
              "-module(z_target).\n-export([f/0]).\nf() -> 1.\n",
            )
            compile_source("a_loader.erl", "debug_info")
            project_config() |> coverage.start() |> start_error()
          })
          |> should
          |> be_equal(
            Ok(
              Ok(ModuleNotInstrumented(
                "z_target",
                "src/z_target.erl",
                AlreadyInstrumented,
                "{already_cover_compiled,no_beam_found,z_target}",
              )),
            ),
          )
          |> or_fail_with("expected AlreadyInstrumented")
        },
      ),
      it(
        "returns InstrumentedLoadFailed when the instrumented module fails to load",
        fn() {
          run_in_child(fn() {
            start_on_compiled_module(
              "flaky.erl",
              "-module(flaky).\n-on_load(init/0).\n"
                <> "init() -> case persistent_term:get(flaky, false) of\n"
                <> "  false -> persistent_term:put(flaky, true), ok;\n"
                <> "  true -> not_ok\nend.\n",
              "debug_info",
            )
          })
          |> should
          |> be_equal(
            Ok(
              Ok(ModuleNotInstrumented(
                "flaky",
                "src/flaky.erl",
                InstrumentedLoadFailed,
                "",
              )),
            ),
          )
          |> or_fail_with("expected InstrumentedLoadFailed")
        },
      ),
      it(
        "returns UnknownInstrumentError when cover returns another error",
        fn() {
          run_in_child(fn() {
            stub_cover("compile_returns_error")
            fixture_config() |> coverage.start() |> start_error()
          })
          |> should
          |> be_equal(
            Ok(
              Ok(ModuleNotInstrumented(
                "coverage_fixture_ffi",
                ffi_path(),
                UnknownInstrumentError,
                "boom",
              )),
            ),
          )
          |> or_fail_with("expected UnknownInstrumentError with boom")
        },
      ),
      it("returns UnknownInstrumentError when cover raises", fn() {
        run_in_child(fn() {
          stub_cover("compile_raises")
          fixture_config() |> coverage.start() |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotInstrumented(
              "coverage_fixture_ffi",
              ffi_path(),
              UnknownInstrumentError,
              "{error,boom}",
            )),
          ),
        )
        |> or_fail_with("expected UnknownInstrumentError with {error,boom}")
      }),
    ]),

    group("module is not analysed", [
      it("returns NotInstrumented when cover stops during the run", fn() {
        run_in_child(fn() {
          measure(fixture_config(), stop_cover) |> finish_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotAnalysed(
              "coverage_fixture_ffi",
              ffi_path(),
              NotInstrumented,
              "{not_cover_compiled,coverage_fixture_ffi}",
            )),
          ),
        )
        |> or_fail_with("expected NotInstrumented")
      }),
      it("returns UnknownAnalysisError when cover returns another error", fn() {
        run_in_child(fn() {
          measure(fixture_config(), fn() { stub_cover("analyse_returns_error") })
          |> finish_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotAnalysed(
              "coverage_fixture_ffi",
              ffi_path(),
              UnknownAnalysisError,
              "boom",
            )),
          ),
        )
        |> or_fail_with("expected UnknownAnalysisError with boom")
      }),
      it("returns UnknownAnalysisError when cover raises", fn() {
        run_in_child(fn() {
          measure(fixture_config(), fn() { stub_cover("analyse_raises") })
          |> finish_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotAnalysed(
              "coverage_fixture_ffi",
              ffi_path(),
              UnknownAnalysisError,
              "{error,boom}",
            )),
          ),
        )
        |> or_fail_with("expected UnknownAnalysisError with {error,boom}")
      }),
    ]),
  ])
}
