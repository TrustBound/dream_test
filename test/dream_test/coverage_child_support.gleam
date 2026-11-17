//// Helpers for the coverage tests that need a child node.
////
//// Most coverage tests run in the test run's own BEAM (see
//// `coverage_project_support`). A test runs in a child node only when it
//// changes something that belongs to the whole BEAM: the code server mode
//// (embedded mode), the working directory (a project of `.gleam` files,
//// whose module names start at the `src` or `dev` folder of the working
//// directory), or an environment variable.

/// Run a function in a new child node.
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

/// In a child: compile src/<file> into ebin/ with debug information.
@external(erlang, "dream_test_coverage_test_ffi", "compile_source")
pub fn compile_source(file: String) -> Nil

/// In a child: build ebin/<module>.beam as Gleam before 1.19 does, by
/// compiling generated Erlang source from a `.erl` file.
@external(erlang, "dream_test_coverage_test_ffi", "compile_like_old_gleam")
pub fn compile_like_old_gleam(module: String, erlang_source: String) -> Nil

/// In a child: build ebin/<module>.beam as Gleam 1.19 does, by compiling
/// abstract code directly with a `-file` attribute for `gleam_path`.
@external(erlang, "dream_test_coverage_test_ffi", "compile_like_new_gleam")
pub fn compile_like_new_gleam(
  module: String,
  erlang_source: String,
  gleam_path: String,
) -> Nil
