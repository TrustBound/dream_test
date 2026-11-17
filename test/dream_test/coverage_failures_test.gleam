//// Every way `coverage.start` and `coverage.finish` can fail, triggered for
//// real. Most tests build a small Erlang project in this BEAM. The
//// embedded-mode test and the dev-folder test run in a child node, because
//// they need a BEAM in embedded mode or a different working directory.

import dream_test/coverage.{
  type CoverageError, type CoverageSession, AlreadyInstrumented, BadBeamFile,
  CompilerNotLoaded, DebugInfoUnreadable, EmbeddedMode, EncryptedDebugInfo,
  InstrumentedLoadFailed, ModuleAlreadyMeasured, ModuleNotAnalysed,
  ModuleNotBuilt, ModuleNotInstrumented, ModuleNotLoaded,
  NativeCoverageUnsupported, NoDebugInfo, NotInstrumented, OldCodeInUse,
  OnLoadFailed, RecompileFailed, SessionAlreadyFinished,
}
import dream_test/coverage_child_support.{
  child_project, run_in_child, run_in_embedded_child,
}
import dream_test/coverage_project_support.{
  add_damaged_beam, add_line_counters_like_another_tool, add_source,
  compile_source, delete_beam, load_module, load_original, measure, project,
  project_config, run_old_code, stop_process,
}
import dream_test/file.{write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/dynamic.{type Dynamic}

/// The start of a measurement of no modules, in a runtime with the given
/// facts. Only its error is used.
@external(erlang, "dream_test_coverage_project_ffi", "start_measuring_for")
fn start_measuring_for(
  supported: Bool,
  compiler_loaded: Bool,
  otp_release: String,
  emulator_flavor: String,
) -> Result(Dynamic, CoverageError)

fn measuring_error(
  result: Result(Dynamic, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected the measurement not to start")
  }
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

/// The error with its raw Erlang term removed, for errors whose raw term
/// holds an absolute path or a process id.
fn without_raw(error: CoverageError) -> CoverageError {
  case error {
    ModuleNotInstrumented(module_name, source_path, cause, _raw) ->
      ModuleNotInstrumented(module_name, source_path, cause, "")
    ModuleNotAnalysed(module_name, source_path, cause, _raw) ->
      ModuleNotAnalysed(module_name, source_path, cause, "")
    other -> other
  }
}

/// Create a project with one module, compiled with `kind` debug
/// information, and start coverage on it.
fn start_on_compiled_module(
  name: String,
  file: String,
  text: String,
  kind: String,
) -> Result(CoverageError, String) {
  let source_directory = project(name)
  add_source(source_directory, file, text)
  compile_source(source_directory, file, kind)
  project_config(source_directory)
  |> coverage.start()
  |> start_error()
  |> result_without_raw()
}

fn result_without_raw(
  result: Result(CoverageError, String),
) -> Result(CoverageError, String) {
  case result {
    Ok(error) -> Ok(without_raw(error))
    Error(message) -> Error(message)
  }
}

/// Create a project with one compiled module, and return its source
/// directory.
fn compiled_project(name: String, module: String) -> String {
  let source_directory = project(name)
  add_source(
    source_directory,
    module <> ".erl",
    "-module(" <> module <> ").\n-export([f/0]).\nf() -> 1.\n",
  )
  compile_source(source_directory, module <> ".erl", "debug_info")
  source_directory
}

pub fn tests() {
  describe("coverage failures", [
    group("runtime", [
      it("returns NativeCoverageUnsupported when the BEAM has no JIT", fn() {
        start_measuring_for(False, True, "29", "emu")
        |> measuring_error()
        |> should
        |> be_equal(Ok(NativeCoverageUnsupported("29", "emu")))
        |> or_fail_with("expected NativeCoverageUnsupported")
      }),
      it("returns CompilerNotLoaded when the compiler does not load", fn() {
        start_measuring_for(True, False, "29", "jit")
        |> measuring_error()
        |> should
        |> be_equal(Ok(CompilerNotLoaded(ModuleNotBuilt, "nofile")))
        |> or_fail_with("expected CompilerNotLoaded")
      }),
    ]),

    group("module does not load", [
      it("returns ModuleNotBuilt for a source file with no .beam", fn() {
        let source_directory = project("not_built")
        add_source(
          source_directory,
          "failures_ghost.erl",
          "-module(failures_ghost).\n",
        )
        project_config(source_directory)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(
          Ok(ModuleNotLoaded(
            "failures_ghost",
            "test/../build/coverage/projects/not_built/src/failures_ghost.erl",
            ModuleNotBuilt,
            "nofile",
          )),
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
        let source_directory = project("on_load")
        add_source(
          source_directory,
          "failures_on_load.erl",
          "-module(failures_on_load).\n-on_load(init/0).\ninit() -> not_ok.\n",
        )
        compile_source(source_directory, "failures_on_load.erl", "debug_info")
        project_config(source_directory)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(
          Ok(ModuleNotLoaded(
            "failures_on_load",
            "test/../build/coverage/projects/on_load/src/failures_on_load.erl",
            OnLoadFailed,
            "on_load_failure",
          )),
        )
        |> or_fail_with("expected OnLoadFailed")
      }),
      it("returns BadBeamFile for a damaged .beam", fn() {
        let source_directory = project("damaged")
        add_source(
          source_directory,
          "failures_damaged.erl",
          "-module(failures_damaged).\n",
        )
        add_damaged_beam(source_directory, "failures_damaged")
        project_config(source_directory)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(
          Ok(ModuleNotLoaded(
            "failures_damaged",
            "test/../build/coverage/projects/damaged/src/failures_damaged.erl",
            BadBeamFile,
            "badfile",
          )),
        )
        |> or_fail_with("expected BadBeamFile")
      }),
      it("returns EmbeddedMode when the BEAM runs in embedded mode", fn() {
        run_in_embedded_child(fn() {
          let source_directory = project("embedded")
          add_source(
            source_directory,
            "failures_embedded.erl",
            "-module(failures_embedded).\n",
          )
          project_config(source_directory)
          |> coverage.start()
          |> start_error()
        })
        |> should
        |> be_equal(
          Ok(
            Ok(ModuleNotLoaded(
              "failures_embedded",
              "test/../build/coverage/projects/embedded/src/failures_embedded.erl",
              EmbeddedMode,
              "embedded",
            )),
          ),
        )
        |> or_fail_with("expected EmbeddedMode")
      }),
    ]),

    group("module gets no line counters", [
      it("returns NoDebugInfo for a .beam without debug information", fn() {
        start_on_compiled_module(
          "no_debug_info",
          "failures_plain.erl",
          "-module(failures_plain).\n-export([f/0]).\nf() -> 1.\n",
          "no_debug_info",
        )
        |> should
        |> be_equal(
          Ok(ModuleNotInstrumented(
            "failures_plain",
            "test/../build/coverage/projects/no_debug_info/src/failures_plain.erl",
            NoDebugInfo,
            "",
          )),
        )
        |> or_fail_with("expected NoDebugInfo")
      }),
      it(
        "returns NoDebugInfo when the debug information backend is missing",
        fn() {
          start_on_compiled_module(
            "missing_backend",
            "failures_backend.erl",
            "-module(failures_backend).\n-export([f/0]).\nf() -> 1.\n",
            "missing_debug_info_backend",
          )
          |> should
          |> be_equal(
            Ok(ModuleNotInstrumented(
              "failures_backend",
              "test/../build/coverage/projects/missing_backend/src/failures_backend.erl",
              NoDebugInfo,
              "",
            )),
          )
          |> or_fail_with("expected NoDebugInfo for a missing backend")
        },
      ),
      it("returns EncryptedDebugInfo for encrypted debug information", fn() {
        start_on_compiled_module(
          "encrypted",
          "failures_secret.erl",
          "-module(failures_secret).\n-export([f/0]).\nf() -> 1.\n",
          "encrypted_debug_info",
        )
        |> should
        |> be_equal(
          Ok(ModuleNotInstrumented(
            "failures_secret",
            "test/../build/coverage/projects/encrypted/src/failures_secret.erl",
            EncryptedDebugInfo,
            "",
          )),
        )
        |> or_fail_with("expected EncryptedDebugInfo")
      }),
      it("returns DebugInfoUnreadable when the .beam file is gone", fn() {
        let source_directory =
          compiled_project("beam_deleted", "failures_deleted")
        load_module("failures_deleted")
        delete_beam(source_directory, "failures_deleted")
        project_config(source_directory)
        |> coverage.start()
        |> start_error()
        |> result_without_raw()
        |> should
        |> be_equal(
          Ok(ModuleNotInstrumented(
            "failures_deleted",
            "test/../build/coverage/projects/beam_deleted/src/failures_deleted.erl",
            DebugInfoUnreadable,
            "",
          )),
        )
        |> or_fail_with("expected DebugInfoUnreadable")
      }),
      it(
        "returns AlreadyInstrumented when another tool gave the module line counters",
        fn() {
          let source_directory =
            compiled_project("other_tool", "failures_other_tool")
          add_line_counters_like_another_tool("failures_other_tool")
          project_config(source_directory)
          |> coverage.start()
          |> start_error()
          |> should
          |> be_equal(
            Ok(ModuleNotInstrumented(
              "failures_other_tool",
              "test/../build/coverage/projects/other_tool/src/failures_other_tool.erl",
              AlreadyInstrumented,
              "{coverage_mode,line_counters}",
            )),
          )
          |> or_fail_with("expected AlreadyInstrumented")
        },
      ),
      it("returns RecompileFailed when the compiler rejects the code", fn() {
        start_on_compiled_module(
          "uncompilable",
          "failures_uncompilable.erl",
          "-module(failures_uncompilable).\n-export([f/0]).\nf() -> 1.\n",
          "uncompilable_debug_info",
        )
        |> should
        |> be_equal(
          Ok(ModuleNotInstrumented(
            "failures_uncompilable",
            "test/../build/coverage/projects/uncompilable/src/failures_uncompilable.erl",
            RecompileFailed,
            "",
          )),
        )
        |> or_fail_with("expected RecompileFailed")
      }),
      it("returns OldCodeInUse when a process runs old code", fn() {
        let source_directory = project("old_code")
        add_source(
          source_directory,
          "failures_old_code.erl",
          "-module(failures_old_code).\n-export([wait/0]).\nwait() -> receive stop -> ok end.\n",
        )
        compile_source(source_directory, "failures_old_code.erl", "debug_info")
        let process = run_old_code("failures_old_code")
        let result =
          project_config(source_directory)
          |> coverage.start()
          |> start_error()
          |> result_without_raw()
        stop_process(process)
        result
        |> should
        |> be_equal(
          Ok(ModuleNotInstrumented(
            "failures_old_code",
            "test/../build/coverage/projects/old_code/src/failures_old_code.erl",
            OldCodeInUse,
            "",
          )),
        )
        |> or_fail_with("expected OldCodeInUse")
      }),
      it(
        "returns InstrumentedLoadFailed when the module with counters fails to load",
        fn() {
          start_on_compiled_module(
            "flaky",
            "failures_flaky.erl",
            "-module(failures_flaky).\n-on_load(init/0).\ninit() -> case persistent_term:get(failures_flaky, false) of false -> persistent_term:put(failures_flaky, true), ok; true -> not_ok end.\n",
            "debug_info",
          )
          |> should
          |> be_equal(
            Ok(ModuleNotInstrumented(
              "failures_flaky",
              "test/../build/coverage/projects/flaky/src/failures_flaky.erl",
              InstrumentedLoadFailed,
              "",
            )),
          )
          |> or_fail_with("expected InstrumentedLoadFailed")
        },
      ),
      it(
        "returns ModuleAlreadyMeasured when another run measures the module",
        fn() {
          let source_directory =
            compiled_project("measured_twice", "failures_twice")
          let config = project_config(source_directory)
          let assert Ok(first) = coverage.start(config)
          let second = coverage.start(config) |> start_error()
          let _ = coverage.finish(first)
          second
          |> should
          |> be_equal(
            Ok(ModuleAlreadyMeasured(
              "failures_twice",
              "test/../build/coverage/projects/measured_twice/src/failures_twice.erl",
            )),
          )
          |> or_fail_with("expected ModuleAlreadyMeasured")
        },
      ),
    ]),

    group("finish", [
      it("returns NotInstrumented when the module is loaded again", fn() {
        let source_directory = compiled_project("reloaded", "failures_reloaded")
        measure(project_config(source_directory), fn() {
          load_original("failures_reloaded")
        })
        |> finish_error()
        |> result_without_raw()
        |> should
        |> be_equal(
          Ok(ModuleNotAnalysed(
            "failures_reloaded",
            "test/../build/coverage/projects/reloaded/src/failures_reloaded.erl",
            NotInstrumented,
            "",
          )),
        )
        |> or_fail_with("expected NotInstrumented")
      }),
      it("returns SessionAlreadyFinished when finish runs twice", fn() {
        let source_directory =
          compiled_project("finished_twice", "failures_finished")
        let assert Ok(session) =
          coverage.start(project_config(source_directory))
        let _ = coverage.finish(session)
        coverage.finish(session)
        |> finish_error()
        |> should
        |> be_equal(Ok(SessionAlreadyFinished))
        |> or_fail_with("expected SessionAlreadyFinished")
      }),
    ]),
  ])
}
