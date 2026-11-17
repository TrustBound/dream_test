//// Line coverage for the code under test.
////
//// Coverage uses the BEAM `cover` tool. When a run starts, every module built
//// from your project's `src` directory is replaced with an instrumented copy.
//// When the run ends, the runner counts how many times each line ran, prints a
//// table, and writes an LCOV file that editors and CI services can read.
////
//// Coverage is opt-in. Turn it on from your test `main` with
//// `runner.coverage(coverage.new())`.
////
//// ## Basic Pattern
////
//// ```gleam
//// import dream_test/coverage
//// import dream_test/reporters/bdd
//// import dream_test/runner
////
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.results_reporters([bdd.new()])
////   |> runner.coverage(coverage.new())
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```
////
//// ## What is measured
////
//// - Modules built from `.gleam` files under the source directory
////   (`src/a/b.gleam` is module `a@b`).
//// - Modules built from `.erl` files under the source directory.
////
//// Test modules, dependencies and the generated `@@main` module are not
//// measured: none of them is built from the source directory.
////
//// ## Line accuracy
////
//// Line numbers come from the compiled `.beam` file. Gleam 1.19 and later map
//// every line to its Gleam source line. Older Gleam versions map only the first
//// line of each function, so lines inside a function can drift.
////
//// ## Limits
////
//// - One coverage run per BEAM instance. A second `start` fails with
////   `CoverStartFailed`, because the `cover` server is already running.
//// - Code that was already running when coverage started keeps running the
////   original module. Calls made after `start` run the instrumented copy.
////
//// ## Available Functions
////
//// | Category      | Functions                                                |
//// |---------------|----------------------------------------------------------|
//// | **Config**    | `new`, `source_directory`, `lcov_path`, `no_lcov`        |
//// | **Run**       | `start`, `finish`                                        |
//// | **Report**    | `hit_line_count`, `executable_line_count`, `render_lcov` |
//// | **Files**     | `write_lcov`, `module_name_from_source_path`             |
//// | **Errors**    | `error_to_string`                                        |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage
//// ```

import dream_test/file.{type FileError}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// =============================================================================
// Types
// =============================================================================

/// Settings for a coverage run.
///
/// Create one with `coverage.new()` and pass it to `runner.coverage`.
pub opaque type CoverageConfig {
  CoverageConfig(source_directory: String, lcov_path: Option(String))
}

/// A module that is instrumented for this run.
///
/// - `module_name`: the BEAM module name, for example `dream_test@sandbox`
/// - `source_path`: the source file, for example `src/dream_test/sandbox.gleam`
pub type CoveredModule {
  CoveredModule(module_name: String, source_path: String)
}

/// A coverage run that has started.
///
/// Only `coverage.start` creates one. Pass it to `coverage.finish`.
pub opaque type CoverageSession {
  CoverageSession(config: CoverageConfig, modules: List(CoveredModule))
}

/// How many times one executable line ran.
pub type LineCoverage {
  LineCoverage(line: Int, calls: Int)
}

/// The executable lines of one source file, sorted by line number.
pub type FileCoverage {
  FileCoverage(source_path: String, lines: List(LineCoverage))
}

/// The result of a coverage run.
///
/// - `files`: one entry per measured source file, sorted by path
/// - `lcov_path`: where the LCOV file was written, if one was written
pub type CoverageReport {
  CoverageReport(files: List(FileCoverage), lcov_path: Option(String))
}

/// Everything that can go wrong during a coverage run.
pub type CoverageError {
  /// The configured source directory does not exist.
  SourceDirectoryNotFound(path: String)
  /// The `cover` server did not start (for example, it was already running).
  CoverStartFailed(reason: String)
  /// A module built from the source directory could not be loaded.
  ModuleNotLoaded(module_name: String, reason: String)
  /// `cover` could not instrument a module.
  ModuleCompileFailed(module_name: String, reason: String)
  /// `cover` could not read the call counts of a module.
  AnalysisFailed(module_name: String, reason: String)
  /// The LCOV file could not be written.
  LcovWriteFailed(path: String, error: FileError)
}

// =============================================================================
// Config
// =============================================================================

/// Create the default coverage settings.
///
/// - Source directory: `src`
/// - LCOV file: `build/coverage/lcov.info`
///
/// ## Example
///
/// ```gleam
/// runner.new([tests()])
/// |> runner.coverage(coverage.new())
/// |> runner.run()
/// ```
pub fn new() -> CoverageConfig {
  CoverageConfig(
    source_directory: "src",
    lcov_path: Some("build/coverage/lcov.info"),
  )
}

/// Measure the modules built from a different source directory.
///
/// The path is relative to the directory that `gleam test` runs in.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.source_directory("src")
/// ```
pub fn source_directory(
  config config: CoverageConfig,
  path path: String,
) -> CoverageConfig {
  CoverageConfig(..config, source_directory: path)
}

/// Write the LCOV file to a different path.
///
/// Parent directories are created when needed.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.lcov_path("build/coverage/unit.lcov")
/// ```
pub fn lcov_path(
  config config: CoverageConfig,
  path path: String,
) -> CoverageConfig {
  CoverageConfig(..config, lcov_path: Some(path))
}

/// Do not write an LCOV file. The table is still printed.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.no_lcov()
/// ```
pub fn no_lcov(config config: CoverageConfig) -> CoverageConfig {
  CoverageConfig(..config, lcov_path: None)
}

// =============================================================================
// Run
// =============================================================================

/// Start the `cover` server and instrument every module built from the source
/// directory.
///
/// Call this before any test runs. The runner does this for you when you use
/// `runner.coverage`.
///
/// ## Returns
///
/// - `Ok(CoverageSession)` when every module is instrumented
/// - `Error(CoverageError)` for the first step that failed
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.source_directory("does/not/exist")
/// |> coverage.start()
/// // -> Error(SourceDirectoryNotFound("does/not/exist"))
/// ```
pub fn start(
  config config: CoverageConfig,
) -> Result(CoverageSession, CoverageError) {
  case list_source_files(config.source_directory) {
    Ok(source_files) ->
      start_with_modules(
        config,
        covered_modules(config.source_directory, source_files, []),
      )
    Error(error) -> Error(error)
  }
}

fn start_with_modules(
  config: CoverageConfig,
  modules: List(CoveredModule),
) -> Result(CoverageSession, CoverageError) {
  case start_cover() {
    Ok(Nil) -> compile_session(config, modules)
    Error(error) -> Error(error)
  }
}

fn compile_session(
  config: CoverageConfig,
  modules: List(CoveredModule),
) -> Result(CoverageSession, CoverageError) {
  case compile_modules(modules) {
    Ok(Nil) -> Ok(CoverageSession(config: config, modules: modules))
    Error(error) -> Error(error)
  }
}

fn compile_modules(modules: List(CoveredModule)) -> Result(Nil, CoverageError) {
  case modules {
    [] -> Ok(Nil)
    [module, ..rest] -> compile_then_continue(module, rest)
  }
}

fn compile_then_continue(
  module: CoveredModule,
  rest: List(CoveredModule),
) -> Result(Nil, CoverageError) {
  case compile_module(module.module_name) {
    Ok(Nil) -> compile_modules(rest)
    Error(error) -> Error(error)
  }
}

fn covered_modules(
  source_directory: String,
  source_files: List(String),
  accumulated_reversed: List(CoveredModule),
) -> List(CoveredModule) {
  case source_files {
    [] -> list.reverse(accumulated_reversed)
    [relative_path, ..rest] -> {
      let module =
        CoveredModule(
          module_name: module_name_from_source_path(relative_path),
          source_path: source_directory <> "/" <> relative_path,
        )
      covered_modules(source_directory, rest, [module, ..accumulated_reversed])
    }
  }
}

/// Read the call counts, build the report, and write the LCOV file.
///
/// The runner calls this after all tests finish when you use
/// `runner.coverage`.
///
/// ## Returns
///
/// - `Ok(CoverageReport)` with one entry per measured file
/// - `Error(CoverageError)` when a module cannot be analysed or the LCOV file
///   cannot be written
pub fn finish(
  session session: CoverageSession,
) -> Result(CoverageReport, CoverageError) {
  case analyse_modules(session.modules, []) {
    Ok(files) ->
      write_report(CoverageReport(
        files: files,
        lcov_path: session.config.lcov_path,
      ))
    Error(error) -> Error(error)
  }
}

fn analyse_modules(
  modules: List(CoveredModule),
  accumulated_reversed: List(FileCoverage),
) -> Result(List(FileCoverage), CoverageError) {
  case modules {
    [] -> Ok(list.reverse(accumulated_reversed))
    [module, ..rest] ->
      analyse_then_continue(module, rest, accumulated_reversed)
  }
}

fn analyse_then_continue(
  module: CoveredModule,
  rest: List(CoveredModule),
  accumulated_reversed: List(FileCoverage),
) -> Result(List(FileCoverage), CoverageError) {
  case analyse_module(module.module_name) {
    Ok(lines) -> {
      let file_coverage =
        FileCoverage(source_path: module.source_path, lines: lines)
      analyse_modules(rest, [file_coverage, ..accumulated_reversed])
    }
    Error(error) -> Error(error)
  }
}

fn write_report(
  report: CoverageReport,
) -> Result(CoverageReport, CoverageError) {
  case report.lcov_path {
    None -> Ok(report)
    Some(path) -> write_report_to(report, path)
  }
}

fn write_report_to(
  report: CoverageReport,
  path: String,
) -> Result(CoverageReport, CoverageError) {
  case write_lcov(report: report, path: path) {
    Ok(Nil) -> Ok(report)
    Error(error) -> Error(error)
  }
}

// =============================================================================
// Report
// =============================================================================

/// Count the lines of a file that ran at least once.
///
/// ## Example
///
/// ```gleam
/// FileCoverage(source_path: "src/a.gleam", lines: [
///   LineCoverage(line: 1, calls: 3),
///   LineCoverage(line: 2, calls: 0),
/// ])
/// |> coverage.hit_line_count()
/// // -> 1
/// ```
pub fn hit_line_count(file file: FileCoverage) -> Int {
  list.count(file.lines, line_was_hit)
}

fn line_was_hit(line: LineCoverage) -> Bool {
  line.calls > 0
}

/// Count the executable lines of a file.
///
/// Blank lines, comments and type definitions are not executable.
///
/// ## Example
///
/// ```gleam
/// FileCoverage(source_path: "src/a.gleam", lines: [
///   LineCoverage(line: 1, calls: 3),
///   LineCoverage(line: 2, calls: 0),
/// ])
/// |> coverage.executable_line_count()
/// // -> 2
/// ```
pub fn executable_line_count(file file: FileCoverage) -> Int {
  list.length(file.lines)
}

/// Render a report in LCOV format.
///
/// Each file gets one record: `SF` (source file), one `DA` (line, calls) per
/// executable line, `LF` (lines found), `LH` (lines hit) and `end_of_record`.
///
/// ## Example
///
/// ```gleam
/// CoverageReport(files: [
///   FileCoverage(source_path: "src/a.gleam", lines: [
///     LineCoverage(line: 1, calls: 3),
///   ]),
/// ], lcov_path: None)
/// |> coverage.render_lcov()
/// // -> "TN:\nSF:src/a.gleam\nDA:1,3\nLF:1\nLH:1\nend_of_record\n"
/// ```
pub fn render_lcov(report report: CoverageReport) -> String {
  report.files
  |> list.map(render_lcov_record)
  |> string.concat()
}

fn render_lcov_record(file: FileCoverage) -> String {
  "TN:\nSF:"
  <> file.source_path
  <> "\n"
  <> string.concat(list.map(file.lines, render_lcov_line))
  <> "LF:"
  <> int.to_string(executable_line_count(file))
  <> "\nLH:"
  <> int.to_string(hit_line_count(file))
  <> "\nend_of_record\n"
}

fn render_lcov_line(line: LineCoverage) -> String {
  "DA:" <> int.to_string(line.line) <> "," <> int.to_string(line.calls) <> "\n"
}

// =============================================================================
// Files
// =============================================================================

/// Write a report to a file in LCOV format.
///
/// Parent directories are created when needed.
///
/// ## Example
///
/// ```gleam
/// coverage.write_lcov(report: report, path: "build/coverage/lcov.info")
/// ```
pub fn write_lcov(
  report report: CoverageReport,
  path path: String,
) -> Result(Nil, CoverageError) {
  case file.write(path, render_lcov(report)) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(LcovWriteFailed(path: path, error: error))
  }
}

/// Return the BEAM module name for a source file.
///
/// The path is relative to the source directory.
///
/// - Gleam: `/` becomes `@` and the extension is removed
///   (`dream_test/sandbox.gleam` is `dream_test@sandbox`).
/// - Erlang: the file name without its extension
///   (`ffi/sandbox_ffi.erl` is `sandbox_ffi`).
///
/// ## Example
///
/// ```gleam
/// coverage.module_name_from_source_path("dream_test/sandbox.gleam")
/// // -> "dream_test@sandbox"
/// ```
pub fn module_name_from_source_path(path path: String) -> String {
  case string.ends_with(path, ".erl") {
    True -> erlang_module_name(path)
    False -> gleam_module_name(path)
  }
}

fn gleam_module_name(path: String) -> String {
  path
  |> string.drop_end(string.length(".gleam"))
  |> string.replace("/", "@")
}

fn erlang_module_name(path: String) -> String {
  path
  |> base_name()
  |> string.drop_end(string.length(".erl"))
}

// =============================================================================
// Errors
// =============================================================================

/// Describe a coverage error in one line.
///
/// ## Example
///
/// ```gleam
/// coverage.error_to_string(SourceDirectoryNotFound("lib"))
/// // -> "Coverage source directory not found: lib"
/// ```
pub fn error_to_string(error error: CoverageError) -> String {
  case error {
    SourceDirectoryNotFound(path) ->
      "Coverage source directory not found: " <> path
    CoverStartFailed(reason) -> "Coverage could not start cover: " <> reason
    ModuleNotLoaded(module_name, reason) ->
      "Coverage could not load module " <> module_name <> ": " <> reason
    ModuleCompileFailed(module_name, reason) ->
      "Coverage could not instrument module " <> module_name <> ": " <> reason
    AnalysisFailed(module_name, reason) ->
      "Coverage could not analyse module " <> module_name <> ": " <> reason
    LcovWriteFailed(path, error) ->
      "Coverage could not write LCOV file "
      <> path
      <> ": "
      <> file.error_to_string(error)
  }
}

// =============================================================================
// Erlang
// =============================================================================

@external(erlang, "dream_test_coverage_ffi", "start_cover")
fn start_cover() -> Result(Nil, CoverageError)

@external(erlang, "dream_test_coverage_ffi", "list_source_files")
fn list_source_files(directory: String) -> Result(List(String), CoverageError)

@external(erlang, "dream_test_coverage_ffi", "compile_module")
fn compile_module(module_name: String) -> Result(Nil, CoverageError)

@external(erlang, "dream_test_coverage_ffi", "analyse_module")
fn analyse_module(
  module_name: String,
) -> Result(List(LineCoverage), CoverageError)

@external(erlang, "filename", "basename")
fn base_name(path: String) -> String
