//// Black-box tests of how coverage finds files with inexact line numbers.
////
//// Gleam before 1.19 writes Erlang source and compiles it, and Gleam 1.19
//// compiles abstract code directly. Each test builds a module both ways in a
//// child node, from the Erlang source that Gleam 1.14 generated for
//// `legacy.gleam`, and checks `report.inexact_line_files`. The tests run in
//// a child node because the module names of `.gleam` files start at the
//// `src` folder of the working directory, and each project needs its own.

import dream_test/child_timeout.{describe_with_child_timeout}
import dream_test/coverage
import dream_test/coverage/report
import dream_test/coverage_child_support.{
  add_source, child_project, compile_like_new_gleam, compile_like_old_gleam,
  compile_source, run_in_child,
}
import dream_test/coverage_project_support.{measure}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{it}
import gleam/result

fn gleam_source() -> String {
  "pub fn classify(number: Int) -> String {\n"
  <> "  case number {\n"
  <> "    0 -> \"zero\"\n"
  <> "    _ -> \"other\"\n"
  <> "  }\n"
  <> "}\n"
}

/// The Erlang source Gleam 1.14 generates for `gleam_source()` in
/// src/legacy.gleam.
fn generated_erlang_source() -> String {
  generated_erlang_source_for("legacy")
}

fn generated_erlang_source_for(module: String) -> String {
  "-module("
  <> module
  <> ").\n"
  <> "-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).\n"
  <> "-define(FILEPATH, \"src/"
  <> module
  <> ".gleam\").\n"
  <> "-export([classify/1]).\n"
  <> "\n"
  <> "-file(\"src/"
  <> module
  <> ".gleam\", 1).\n"
  <> "-spec classify(integer()) -> binary().\n"
  <> "classify(Number) ->\n"
  <> "    case Number of\n"
  <> "        0 ->\n"
  <> "            <<\"zero\"/utf8>>;\n"
  <> "\n"
  <> "        _ ->\n"
  <> "            <<\"other\"/utf8>>\n"
  <> "    end.\n"
}

fn erlang_ffi_source() -> String {
  "-module(legacy_ffi).\n-export([answer/0]).\nanswer() -> 42.\n"
}

fn project_config() {
  coverage.new() |> coverage.no_lcov()
}

fn inexact_line_files_of_project() -> Result(List(String), String) {
  measure(project_config(), fn() { Nil })
  |> result.map(report.inexact_line_files)
  |> result.map_error(fn(_error) { "coverage failed" })
}

pub fn tests() {
  describe_with_child_timeout("coverage line accuracy", [
    it("marks a .gleam file built from generated Erlang source", fn() {
      run_in_child(fn() {
        let _ = child_project("old_gleam")
        add_source("legacy.gleam", gleam_source())
        compile_like_old_gleam("legacy", generated_erlang_source())
        inexact_line_files_of_project()
      })
      |> should
      |> be_equal(Ok(Ok(["src/legacy.gleam"])))
      |> or_fail_with("expected src/legacy.gleam to be marked")
    }),
    it("lists marked files sorted by path", fn() {
      run_in_child(fn() {
        let _ = child_project("old_gleam_sorted")
        add_source("zebra.gleam", gleam_source())
        add_source("apple.gleam", gleam_source())
        compile_like_old_gleam("zebra", generated_erlang_source_for("zebra"))
        compile_like_old_gleam("apple", generated_erlang_source_for("apple"))
        inexact_line_files_of_project()
      })
      |> should
      |> be_equal(Ok(Ok(["src/apple.gleam", "src/zebra.gleam"])))
      |> or_fail_with("expected apple, then zebra")
    }),
    it("does not mark a .gleam file built from abstract code", fn() {
      run_in_child(fn() {
        let _ = child_project("new_gleam")
        add_source("legacy.gleam", gleam_source())
        compile_like_new_gleam(
          "legacy",
          generated_erlang_source(),
          "src/legacy.gleam",
        )
        inexact_line_files_of_project()
      })
      |> should
      |> be_equal(Ok(Ok([])))
      |> or_fail_with("expected no marked files")
    }),
    it("does not mark an .erl file", fn() {
      run_in_child(fn() {
        let _ = child_project("erlang_source")
        add_source("legacy_ffi.erl", erlang_ffi_source())
        compile_source("legacy_ffi.erl")
        inexact_line_files_of_project()
      })
      |> should
      |> be_equal(Ok(Ok([])))
      |> or_fail_with("expected no marked files")
    }),
    it("does not mark the fixture modules that Gleam 1.19 built", fn() {
      run_in_child(fn() {
        measure(
          coverage.new()
            |> coverage.source_directory("test/coverage_fixtures")
            |> coverage.no_lcov(),
          fn() { Nil },
        )
        |> result.map(report.inexact_line_files)
        |> result.map_error(fn(_error) { "coverage failed" })
      })
      |> should
      |> be_equal(Ok(Ok([])))
      |> or_fail_with("expected no marked fixture files")
    }),
  ])
}
