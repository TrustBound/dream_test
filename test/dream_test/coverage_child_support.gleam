//// Shared helpers for the coverage tests that run in a child node.
////
//// See test/dream_test_coverage_test_ffi.erl for how a child node measures
//// dream_test's own coverage code.

import dream_test/coverage.{
  type CoverageConfig, type CoverageError, CoverStartFailed, ModuleNotAnalysed,
  ModuleNotInstrumented, ModuleNotLoaded,
}
import dream_test/coverage/report.{type CoverageReport}

/// Run a function in a new child node with native line counters.
@external(erlang, "dream_test_coverage_test_ffi", "run_in_peer")
pub fn run_in_child(function: fn() -> a) -> Result(a, String)

/// The same, in a child that runs in embedded mode.
@external(erlang, "dream_test_coverage_test_ffi", "run_in_embedded_peer")
pub fn run_in_embedded_child(function: fn() -> a) -> Result(a, String)

/// In a child: create an empty project and make it the working directory.
@external(erlang, "dream_test_coverage_test_ffi", "child_project")
pub fn child_project(name: String) -> String

/// In a child: write src/<file> in the current project.
@external(erlang, "dream_test_coverage_test_ffi", "add_source")
pub fn add_source(file: String, text: String) -> Nil

/// In a child: compile src/<file> into ebin/. `kind` is `debug_info`,
/// `no_debug_info`, `encrypted_debug_info` or `missing_debug_info_backend`.
@external(erlang, "dream_test_coverage_test_ffi", "compile_source")
pub fn compile_source(file: String, kind: String) -> Nil

/// In a child: write a damaged ebin/<module>.beam.
@external(erlang, "dream_test_coverage_test_ffi", "add_damaged_beam")
pub fn add_damaged_beam(module: String) -> Nil

/// In a child: replace `cover` with a stub that fails in one way.
@external(erlang, "dream_test_coverage_test_ffi", "stub_cover")
pub fn stub_cover(kind: String) -> Nil

/// In a child: stop the real `cover` server.
@external(erlang, "dream_test_coverage_test_ffi", "stop_cover")
pub fn stop_cover() -> Nil

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

/// The error with its raw Erlang term removed, for errors whose raw term
/// holds an absolute path or a process id.
pub fn without_raw(error: CoverageError) -> CoverageError {
  case error {
    CoverStartFailed(cause, _raw) -> CoverStartFailed(cause, "")
    ModuleNotLoaded(module_name, source_path, cause, _raw) ->
      ModuleNotLoaded(module_name, source_path, cause, "")
    ModuleNotInstrumented(module_name, source_path, cause, _raw) ->
      ModuleNotInstrumented(module_name, source_path, cause, "")
    ModuleNotAnalysed(module_name, source_path, cause, _raw) ->
      ModuleNotAnalysed(module_name, source_path, cause, "")
    other -> other
  }
}
