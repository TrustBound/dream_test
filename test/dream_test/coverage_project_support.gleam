//// Helpers for the coverage tests that build small Erlang projects in the
//// test run's own BEAM.
////
//// See test/dream_test_coverage_project_ffi.erl for where the projects live
//// and how their modules are named.

import dream_test/coverage.{type CoverageConfig, type CoverageError}
import dream_test/coverage/report.{type CoverageReport}
import gleam/dynamic.{type Dynamic}

/// Create an empty project and return its source directory.
@external(erlang, "dream_test_coverage_project_ffi", "project")
pub fn project(name: String) -> String

/// Write `<source_directory>/<file>`.
@external(erlang, "dream_test_coverage_project_ffi", "add_source")
pub fn add_source(source_directory: String, file: String, text: String) -> Nil

/// Compile `<source_directory>/<file>` into the project's ebin/. `kind` is
/// `debug_info`, `no_debug_info`, `encrypted_debug_info`,
/// `missing_debug_info_backend` or `uncompilable_debug_info`.
@external(erlang, "dream_test_coverage_project_ffi", "compile_source")
pub fn compile_source(
  source_directory: String,
  file: String,
  kind: String,
) -> Nil

/// Write a damaged .beam file for `module`.
@external(erlang, "dream_test_coverage_project_ffi", "add_damaged_beam")
pub fn add_damaged_beam(source_directory: String, module: String) -> Nil

/// Delete the .beam file of `module`.
@external(erlang, "dream_test_coverage_project_ffi", "delete_beam")
pub fn delete_beam(source_directory: String, module: String) -> Nil

/// Take away every permission on `<source_directory>/<file>`.
@external(erlang, "dream_test_coverage_project_ffi", "make_unreadable")
pub fn make_unreadable(source_directory: String, file: String) -> Nil

/// Load `module` from its .beam file.
@external(erlang, "dream_test_coverage_project_ffi", "load_module")
pub fn load_module(module: String) -> Nil

/// Give `module` line counters the way another coverage tool would.
@external(erlang, "dream_test_coverage_project_ffi", "add_line_counters_like_another_tool")
pub fn add_line_counters_like_another_tool(module: String) -> Nil

/// The process that `run_old_code` starts.
pub type OldCodeProcess

/// Start a process that runs `module.wait()`, then load `module` again, so
/// the process runs old code.
@external(erlang, "dream_test_coverage_project_ffi", "run_old_code")
pub fn run_old_code(module: String) -> OldCodeProcess

/// Kill a process from `run_old_code`.
@external(erlang, "dream_test_coverage_project_ffi", "stop_process")
pub fn stop_process(process: OldCodeProcess) -> Nil

/// Load `module` again from its .beam file, without line counters.
@external(erlang, "dream_test_coverage_project_ffi", "load_original")
pub fn load_original(module: String) -> Nil

/// Run `work` while no other test measures the shared fixture modules.
@external(erlang, "dream_test_coverage_project_ffi", "with_fixture_lock")
pub fn with_fixture_lock(work: fn() -> a) -> a

/// Start coverage with `config`, run `work`, then finish.
pub fn measure(
  config: CoverageConfig,
  work: fn() -> a,
) -> Result(CoverageReport, CoverageError) {
  case coverage.start(config) {
    Ok(session) -> {
      let _ = work()
      coverage.finish(session)
    }
    Error(error) -> Error(error)
  }
}

/// The coverage settings for a project: its source directory, no LCOV file.
pub fn project_config(source_directory: String) -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory(source_directory)
  |> coverage.no_lcov()
}

/// A process from `start_server`.
pub type ServerProcess

/// Start a process that runs `module.serve()`.
@external(erlang, "dream_test_coverage_project_ffi", "start_server")
pub fn start_server(module: String) -> ServerProcess

/// Ask a process from `start_server` for its answer. Returns `timeout`
/// after one second.
@external(erlang, "dream_test_coverage_project_ffi", "ask")
pub fn ask(process: ServerProcess) -> Dynamic

/// True while the process runs.
@external(erlang, "dream_test_coverage_project_ffi", "is_alive")
pub fn is_alive(process: ServerProcess) -> Bool

/// Call `module.answer()`.
@external(erlang, "dream_test_coverage_project_ffi", "call_answer")
pub fn call_answer(module: String) -> Dynamic
