//// Line coverage for the code under test.
////
//// Coverage uses the BEAM `cover` tool. When a run starts, every module built
//// from your source directory is replaced with an instrumented copy. When the
//// run ends, the runner counts how many times each line ran, prints a table,
//// and writes an LCOV file that editors and CI services can read.
////
//// ## With the dream_test runner
////
//// Coverage is opt-in. Turn it on from your test `main`:
////
//// ```gleam
//// import dream_test/coverage
//// import dream_test/reporters/bdd
//// import dream_test/runner
////
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.results_reporters([bdd.new()])
////   |> runner.coverage(
////     coverage.new()
////     |> coverage.show_missing()
////     |> coverage.minimum_percent(80.0),
////   )
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```
////
//// ## Without the dream_test runner
////
//// `start`, `finish` and `check_minimum` run coverage around any code, for
//// example another test runner. Render the result with
//// `dream_test/reporters/coverage`, or read it with
//// `dream_test/coverage/report`.
////
//// ```gleam
//// let config = coverage.new()
//// let assert Ok(session) = coverage.start(config)
//// run_my_tests()
//// let assert Ok(coverage_report) = coverage.finish(session)
//// io.print(coverage_reporter.render(report: coverage_report, config: config))
//// ```
////
//// ## What is measured
////
//// Modules built from the `.gleam` and `.erl` files under the source
//// directory. The source directory is `src` by default. It can be a folder
//// inside `src`, `test` or `dev` (for example `src/app`), because module names
//// start at those folders: `src/app/cart.gleam` is module `app@cart`.
////
//// `coverage.exclude` removes files from the run, for example generated
//// code. An excluded module is not instrumented and is not in the table, the
//// LCOV file or the minimum.
////
//// ## Ignoring lines
////
//// Comment markers leave lines of a source file out of coverage. Put each
//// marker on its own line. `gleam format` moves a comment at the end of a
//// code line to the next line, so a marker after code is not supported.
////
//// ```gleam
//// pub fn log(message: String) -> Nil {
////   // coverage:ignore
////   io.println(message)
//// }
////
//// // coverage:ignore-start debug helpers
//// pub fn dump(value: a) -> a {
////   echo value
//// }
//// // coverage:ignore-end
////
//// // coverage:ignore-function only old callers use this
//// /// Converts the old record format.
//// @deprecated("Use convert instead")
//// pub fn convert_legacy(record: String) -> String {
////   string.replace(record, ";", ",")
//// }
//// ```
////
//// - `// coverage:ignore` ignores the next line that holds code. Blank lines
////   and comment lines between the marker and the code are skipped.
//// - `// coverage:ignore-start` and `// coverage:ignore-end` ignore every
////   line from the start marker to the end marker.
//// - `// coverage:ignore-function` ignores every line from the marker to the
////   last line of the function after it. Blank lines, comments, doc comments
////   and attributes such as `@external(...)` or `@deprecated(...)` can be
////   between the marker and `fn`. In an `.erl` file, put the marker above the
////   first clause; attributes such as `-spec` can be between them, and every
////   clause up to the dot that ends the function is ignored.
//// - In `.erl` files, write the markers after `%` or `%%`, for example
////   `%% coverage:ignore`.
//// - Text after a marker is a note for the people who read the code.
////
//// An ignored line is not in the table, the Missing column, the LCOV file or
//// the minimum. Line counts on it from `coverage.merge_lcov` are dropped too.
//// Markers are read from each measured file, and from each file that a
//// merged LCOV file covers.
////
//// An ignore-start marker without an ignore-end marker, an ignore-end marker
//// without an ignore-start marker, an ignore-start marker inside an ignored
//// block, and an ignore-function marker that no complete function follows
//// are errors. The error gives the file and the line.
////
//// Markers match exact source lines only on Gleam 1.19 and later. See
//// "Line accuracy".
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
////   `CoverStartFailed(CoverAlreadyRunning, ..)`.
//// - Code that was already running when coverage started keeps running the
////   original module. Calls made after `start` run the instrumented copy.
////
//// ## Errors and versions
////
//// `CoverageError` and its cause types get new variants only in major
//// versions, so a `case` that handles every variant keeps compiling across
//// minor and patch releases.
////
//// ## Available Functions
////
//// | Category     | Functions                                                 |
//// |--------------|-----------------------------------------------------------|
//// | **Settings** | `new`, `source_directory`, `lcov_path`, `no_lcov`,        |
//// |              | `show_missing`, `minimum_percent`, `merge_lcov`,          |
//// |              | `exclude`                                                 |
//// | **Read**     | `shows_missing`, `lcov_file`                              |
//// | **Run**      | `start`, `finish`, `check_minimum`                        |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage
//// ```

import dream_test/coverage/report.{
  type CoverageReport, type FileCoverage, type LineCoverage, LineCoverage,
}
import dream_test/file.{type FileError}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/set.{type Set}
import gleam/string

// =============================================================================
// Types
// =============================================================================

/// Settings for a coverage run.
///
/// Create one with `coverage.new()` and pass it to `runner.coverage`, or to
/// `coverage.start`.
pub opaque type CoverageConfig {
  CoverageConfig(
    source_directory: String,
    lcov_path: Option(String),
    show_missing: Bool,
    minimum_percent: Option(Float),
    merge_lcov_patterns: List(String),
    exclude_patterns: List(String),
  )
}

/// A coverage run that has started.
///
/// Only `coverage.start` creates one. Pass it to `coverage.finish`.
pub opaque type CoverageSession {
  CoverageSession(
    config: CoverageConfig,
    modules: List(CoveredModule),
    excluded_paths: List(String),
    ignored_lines: IgnoredLines,
  )
}

type CoveredModule {
  CoveredModule(module_name: String, source_path: String)
}

/// Everything that can go wrong during a coverage run.
///
/// `dream_test/reporters/coverage.render_failure` turns each one into a
/// message that says what failed, why, and what to do. Variants that come
/// from the BEAM keep the raw Erlang term in `raw`.
///
/// New variants are added only in major versions.
pub type CoverageError {
  /// The source directory does not exist.
  SourceDirectoryNotFound(path: String)
  /// The source directory is not `src`, `test` or `dev`, or a folder inside
  /// one of them, so module names cannot be worked out.
  SourceDirectoryOutsideSourceRoot(path: String)
  /// The source directory holds no `.gleam` or `.erl` files.
  NoSourceFiles(path: String)
  /// The BEAM `cover` tool did not start.
  CoverStartFailed(cause: StartCause, raw: String)
  /// A module built from the source directory could not be loaded.
  ModuleNotLoaded(
    module_name: String,
    source_path: String,
    cause: LoadCause,
    raw: String,
  )
  /// `cover` could not instrument a module.
  ModuleNotInstrumented(
    module_name: String,
    source_path: String,
    cause: InstrumentCause,
    raw: String,
  )
  /// `cover` could not read the call counts of a module.
  ModuleNotAnalysed(
    module_name: String,
    source_path: String,
    cause: AnalysisCause,
    raw: String,
  )
  /// The LCOV file could not be written.
  LcovWriteFailed(path: String, error: FileError)
  /// The value given to `coverage.minimum_percent` is not from 0.0 to 100.0.
  InvalidMinimumPercent(value: Float)
  /// Total coverage is below the value given to `coverage.minimum_percent`.
  ///
  /// - `hit`: executable lines that ran
  /// - `total`: executable lines
  /// - `minimum_percent`: the minimum, rounded to one decimal place
  /// - `lines_needed`: how many lines must run to reach the minimum
  BelowMinimumPercent(
    hit: Int,
    total: Int,
    minimum_percent: Float,
    lines_needed: Int,
  )
  /// No file matches a pattern given to `coverage.merge_lcov`.
  NoLcovFilesMatched(pattern: String)
  /// A file given to `coverage.merge_lcov` could not be read.
  LcovReadFailed(path: String, error: FileError)
  /// A file given to `coverage.merge_lcov` is not valid LCOV.
  ///
  /// - `line_number`: the 1-based line in the LCOV file
  /// - `line`: the text of that line
  /// - `problem`: what is wrong with it
  MalformedLcov(path: String, line_number: Int, line: String, problem: String)
  /// A file given to `coverage.merge_lcov` covers a source file that does not
  /// exist in this project.
  LcovSourceNotFound(lcov_path: String, source_path: String)
  /// A pattern given to `coverage.exclude` matches no `.gleam` or `.erl`
  /// file in the source directory.
  ExcludeMatchedNothing(pattern: String, source_directory: String)
  /// The patterns given to `coverage.exclude` match every `.gleam` and
  /// `.erl` file in the source directory, so nothing is left to measure.
  EverySourceFileExcluded(source_directory: String)
  /// A source file cannot be read to find its ignore markers.
  SourceReadFailed(path: String, error: FileError)
  /// A `coverage:ignore-start` marker has no `coverage:ignore-end` marker
  /// after it.
  ///
  /// - `line_number`: the 1-based line of the start marker
  IgnoreStartWithoutEnd(source_path: String, line_number: Int)
  /// A `coverage:ignore-end` marker has no `coverage:ignore-start` marker
  /// before it.
  ///
  /// - `line_number`: the 1-based line of the end marker
  IgnoreEndWithoutStart(source_path: String, line_number: Int)
  /// A `coverage:ignore-start` marker is inside a block that an earlier
  /// start marker opened. Ignored blocks cannot be nested.
  ///
  /// - `line_number`: the 1-based line of the inner start marker
  /// - `open_line_number`: the line of the start marker that opened the block
  NestedIgnoreStart(
    source_path: String,
    line_number: Int,
    open_line_number: Int,
  )
  /// A `coverage:ignore-function` marker is not followed by a complete
  /// function: the code after it is a constant, a type or other code, or the
  /// file ends first.
  ///
  /// - `line_number`: the 1-based line of the marker
  IgnoreFunctionWithoutFunction(source_path: String, line_number: Int)
}

/// Why the `cover` tool did not start.
pub type StartCause {
  /// `cover` was already running, so another coverage run owns it.
  CoverAlreadyRunning
  /// `cover` returned another error.
  CoverDidNotStart
}

/// Why a module could not be loaded.
pub type LoadCause {
  /// No `.beam` file for the module is on the code path.
  ModuleNotBuilt
  /// The module's `on_load` function failed.
  OnLoadFailed
  /// The `.beam` file is damaged or built for another Erlang version.
  BadBeamFile
  /// The code server runs in embedded mode, which only loads the modules
  /// listed when the BEAM starts.
  EmbeddedMode
}

/// Why `cover` could not instrument a module.
pub type InstrumentCause {
  /// The `.beam` file has no debug information.
  NoDebugInfo
  /// The debug information in the `.beam` file is encrypted.
  EncryptedDebugInfo
  /// Another tool already instrumented the module from source.
  AlreadyInstrumented
  /// The instrumented module could not be loaded.
  InstrumentedLoadFailed
  /// `cover` returned another error.
  UnknownInstrumentError
}

/// Why `cover` could not read the call counts of a module.
pub type AnalysisCause {
  /// The module is no longer instrumented (for example, `cover` was stopped
  /// or reset during the run).
  NotInstrumented
  /// `cover` returned another error.
  UnknownAnalysisError
}

// =============================================================================
// Settings
// =============================================================================

/// Create the default coverage settings.
///
/// - Source directory: `src`
/// - LCOV file: `build/coverage/lcov.info`
/// - Missing lines: not shown
/// - Minimum: none
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
    show_missing: False,
    minimum_percent: None,
    merge_lcov_patterns: [],
    exclude_patterns: [],
  )
}

/// Measure the modules built from a different source directory.
///
/// The path is relative to the directory that `gleam test` runs in. It must
/// be `src`, `test` or `dev`, or a folder inside one of them, for example
/// `src/app`.
///
/// ## Parameters
///
/// - `config`: the settings to change
/// - `path`: the directory to measure
///
/// ## Returns
///
/// The updated settings.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.source_directory("src/app")
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
/// ## Parameters
///
/// - `config`: the settings to change
/// - `path`: the LCOV file to write
///
/// ## Returns
///
/// The updated settings.
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
/// ## Parameters
///
/// - `config`: the settings to change
///
/// ## Returns
///
/// The updated settings.
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

/// Add a `Missing` column to the table that lists the lines that did not run.
///
/// Consecutive line numbers are merged into ranges (`258-260`). Long lists
/// wrap onto more lines in the same column. Off by default.
///
/// The LCOV file always holds every line with its count, so this setting does
/// not change it.
///
/// ## Parameters
///
/// - `config`: the settings to change
///
/// ## Returns
///
/// The updated settings.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.show_missing()
/// ```
pub fn show_missing(config config: CoverageConfig) -> CoverageConfig {
  CoverageConfig(..config, show_missing: True)
}

/// Fail the run when total coverage is below a percent.
///
/// The value must be from `0.0` to `100.0` and is rounded to one decimal
/// place. Coverage passes when it is equal to the minimum or above it. The
/// check is exact: 1999 of 2500 lines (79.96%) fails a minimum of `80.0`.
///
/// With the runner, a failure prints a `Coverage failed` block after the
/// table, and `runner.exit_on_failure` then exits with status 1.
///
/// ## Parameters
///
/// - `config`: the settings to change
/// - `percent`: the minimum total coverage, from `0.0` to `100.0`
///
/// ## Returns
///
/// The updated settings. An out-of-range value is reported by
/// `coverage.start` and `coverage.check_minimum` as `InvalidMinimumPercent`.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.minimum_percent(80.0)
/// ```
pub fn minimum_percent(
  config config: CoverageConfig,
  percent percent: Float,
) -> CoverageConfig {
  CoverageConfig(..config, minimum_percent: Some(percent))
}

/// Add the coverage in other LCOV files to this run's report.
///
/// Use it when code runs in other BEAM instances, for example servers that
/// integration tests start, or helper nodes. Each of those writes an LCOV
/// file (with `coverage.finish`, or any tool that writes LCOV). When this run
/// finishes, every file that matches `pattern` is read and its line counts
/// are added, per file and line, to this run's counts. The table, the LCOV
/// output and `coverage.minimum_percent` then use the combined totals.
///
/// Call it more than once to merge more than one pattern. Each pattern must
/// match at least one file, so a run that silently produced no coverage is
/// reported instead of hidden. Paths in the LCOV files (`SF:` lines) are read
/// from the directory the tests run in, and each must be a file in the
/// project.
///
/// ## Parameters
///
/// - `config`: the settings to change
/// - `pattern`: a wildcard pattern for the LCOV files, for example
///   `build/coverage/parts/*.info`
///
/// ## Returns
///
/// The updated settings.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.merge_lcov("build/coverage/servers/*.info")
/// ```
pub fn merge_lcov(
  config config: CoverageConfig,
  pattern pattern: String,
) -> CoverageConfig {
  CoverageConfig(
    ..config,
    merge_lcov_patterns: list.append(config.merge_lcov_patterns, [pattern]),
  )
}

/// Leave the source files that match a pattern out of coverage.
///
/// Use it for code that tests do not need to cover, for example generated
/// code. An excluded module is not instrumented, and it is not in the table,
/// the LCOV file or `coverage.minimum_percent`. Line counts for it from
/// `coverage.merge_lcov` are dropped too.
///
/// Patterns are wildcards relative to the directory the tests run in, the
/// same as `coverage.merge_lcov`. They are matched against the paths of the
/// `.gleam` and `.erl` files in the source directory, for example
/// `src/app/cart.gleam`. `*` matches inside one folder, and `**` matches any
/// number of folders.
///
/// Call it more than once to exclude more than one pattern. Each pattern must
/// match at least one source file, and at least one source file must be left
/// to measure. Otherwise `coverage.start` returns an error, so a pattern with
/// a typo, or one left behind after the files moved, is reported instead of
/// hidden.
///
/// ## Parameters
///
/// - `config`: the settings to change
/// - `pattern`: a wildcard pattern for the source files, for example
///   `src/app/generated/**` or `src/**/*_ffi.erl`
///
/// ## Returns
///
/// The updated settings.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.exclude("src/app/generated/**")
/// |> coverage.exclude("src/**/*_ffi.erl")
/// ```
pub fn exclude(
  config config: CoverageConfig,
  pattern pattern: String,
) -> CoverageConfig {
  CoverageConfig(
    ..config,
    exclude_patterns: list.append(config.exclude_patterns, [pattern]),
  )
}

// =============================================================================
// Read settings
// =============================================================================

/// Whether `coverage.show_missing` is on.
///
/// Reporters read this to decide whether to list the lines that did not run.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.show_missing()
/// |> coverage.shows_missing()
/// // -> True
/// ```
pub fn shows_missing(config config: CoverageConfig) -> Bool {
  config.show_missing
}

/// The LCOV file that `coverage.finish` writes, if any.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.lcov_file()
/// // -> Some("build/coverage/lcov.info")
/// ```
pub fn lcov_file(config config: CoverageConfig) -> Option(String) {
  config.lcov_path
}

// =============================================================================
// Run
// =============================================================================

/// Start the `cover` tool and instrument every module built from the source
/// directory, except the files that `coverage.exclude` matches.
///
/// Call this before the code you want to measure runs. `runner.coverage`
/// does this for you.
///
/// ## Parameters
///
/// - `config`: the coverage settings
///
/// ## Returns
///
/// - `Ok(CoverageSession)` when every module is instrumented
/// - `Error(CoverageError)` for the first step that failed. Exclude patterns
///   and the ignore markers of the measured files are checked before `cover`
///   starts.
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.source_directory("src/does_not_exist")
/// |> coverage.start()
/// // -> Error(SourceDirectoryNotFound("src/does_not_exist"))
/// ```
pub fn start(
  config config: CoverageConfig,
) -> Result(CoverageSession, CoverageError) {
  case validate_minimum_percent(config.minimum_percent) {
    Ok(Nil) -> start_with_valid_minimum(config)
    Error(error) -> Error(error)
  }
}

fn validate_minimum_percent(
  minimum: Option(Float),
) -> Result(Nil, CoverageError) {
  case minimum {
    None -> Ok(Nil)
    Some(value) if value <. 0.0 || value >. 100.0 ->
      Error(InvalidMinimumPercent(value: value))
    Some(_) -> Ok(Nil)
  }
}

fn start_with_valid_minimum(
  config: CoverageConfig,
) -> Result(CoverageSession, CoverageError) {
  case list_source_files(config.source_directory) {
    Ok(source_files) -> start_with_source_files(config, source_files)
    Error(error) -> Error(error)
  }
}

fn start_with_source_files(
  config: CoverageConfig,
  source_files: List(String),
) -> Result(CoverageSession, CoverageError) {
  case source_files, module_prefix(config.source_directory) {
    _, Error(error) -> Error(error)
    [], _ -> Error(NoSourceFiles(path: config.source_directory))
    _, Ok(prefix) ->
      start_with_all_modules(
        config,
        covered_modules(config.source_directory, prefix, source_files, []),
      )
  }
}

fn start_with_all_modules(
  config: CoverageConfig,
  modules: List(CoveredModule),
) -> Result(CoverageSession, CoverageError) {
  let source_paths = set.from_list(list.map(modules, module_source_path))
  case excluded_source_paths(config, source_paths, set.new()) {
    Ok(excluded) -> start_with_kept_modules(config, modules, excluded)
    Error(error) -> Error(error)
  }
}

fn module_source_path(module: CoveredModule) -> String {
  module.source_path
}

/// The source paths that the exclude patterns match. Fails on the first
/// pattern that matches no source path.
fn excluded_source_paths(
  config: CoverageConfig,
  source_paths: Set(String),
  excluded: Set(String),
) -> Result(Set(String), CoverageError) {
  case config.exclude_patterns {
    [] -> Ok(excluded)
    [pattern, ..rest] ->
      exclude_pattern_then_continue(
        CoverageConfig(..config, exclude_patterns: rest),
        pattern,
        source_paths,
        excluded,
      )
  }
}

fn exclude_pattern_then_continue(
  config: CoverageConfig,
  pattern: String,
  source_paths: Set(String),
  excluded: Set(String),
) -> Result(Set(String), CoverageError) {
  let matched =
    match_files(pattern)
    |> list.map(normalise_path)
    |> set.from_list()
    |> set.intersection(source_paths)
  case set.is_empty(matched) {
    True ->
      Error(ExcludeMatchedNothing(
        pattern: pattern,
        source_directory: config.source_directory,
      ))
    False ->
      excluded_source_paths(config, source_paths, set.union(excluded, matched))
  }
}

/// A path in the form coverage builds source paths: no `.` or empty parts.
fn normalise_path(path: String) -> String {
  string.join(path_segments(path), "/")
}

fn start_with_kept_modules(
  config: CoverageConfig,
  modules: List(CoveredModule),
  excluded: Set(String),
) -> Result(CoverageSession, CoverageError) {
  case kept_modules(modules, excluded, []) {
    [] ->
      Error(EverySourceFileExcluded(source_directory: config.source_directory))
    kept ->
      start_with_ignored_lines(
        config,
        kept,
        list.sort(set.to_list(excluded), string.compare),
      )
  }
}

/// Read the ignore markers of every kept module before `cover` starts, so a
/// bad marker fails the run before the tests run.
fn start_with_ignored_lines(
  config: CoverageConfig,
  modules: List(CoveredModule),
  excluded_paths: List(String),
) -> Result(CoverageSession, CoverageError) {
  case add_ignored_lines(dict.new(), list.map(modules, module_source_path)) {
    Ok(ignored_lines) ->
      start_with_modules(CoverageSession(
        config: config,
        modules: modules,
        excluded_paths: excluded_paths,
        ignored_lines: ignored_lines,
      ))
    Error(error) -> Error(error)
  }
}

fn kept_modules(
  modules: List(CoveredModule),
  excluded: Set(String),
  accumulated_reversed: List(CoveredModule),
) -> List(CoveredModule) {
  case modules {
    [] -> list.reverse(accumulated_reversed)
    [module, ..rest] ->
      kept_modules(
        rest,
        excluded,
        keep_unless_excluded(module, excluded, accumulated_reversed),
      )
  }
}

fn keep_unless_excluded(
  module: CoveredModule,
  excluded: Set(String),
  accumulated_reversed: List(CoveredModule),
) -> List(CoveredModule) {
  case set.contains(excluded, module.source_path) {
    True -> accumulated_reversed
    False -> [module, ..accumulated_reversed]
  }
}

/// The module path segments that come before the files in the source
/// directory: `src` gives `[]`, `src/app` gives `["app"]`.
fn module_prefix(
  source_directory: String,
) -> Result(List(String), CoverageError) {
  case path_segments(source_directory) {
    ["src", ..prefix] -> Ok(prefix)
    ["test", ..prefix] -> Ok(prefix)
    ["dev", ..prefix] -> Ok(prefix)
    _ -> Error(SourceDirectoryOutsideSourceRoot(path: source_directory))
  }
}

fn path_segments(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(is_meaningful_segment)
}

fn is_meaningful_segment(segment: String) -> Bool {
  segment != "" && segment != "."
}

fn start_with_modules(
  session: CoverageSession,
) -> Result(CoverageSession, CoverageError) {
  case start_cover() {
    Ok(Nil) -> compile_session(session)
    Error(error) -> Error(error)
  }
}

fn compile_session(
  session: CoverageSession,
) -> Result(CoverageSession, CoverageError) {
  case compile_modules(session.modules) {
    Ok(Nil) -> Ok(session)
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
  case compile_module(module.module_name, module.source_path) {
    Ok(Nil) -> compile_modules(rest)
    Error(error) -> Error(error)
  }
}

fn covered_modules(
  source_directory: String,
  prefix: List(String),
  source_files: List(String),
  accumulated_reversed: List(CoveredModule),
) -> List(CoveredModule) {
  case source_files {
    [] -> list.reverse(accumulated_reversed)
    [relative_path, ..rest] -> {
      let module =
        CoveredModule(
          module_name: module_name(prefix, relative_path),
          source_path: string.join(
            list.append(path_segments(source_directory), [relative_path]),
            "/",
          ),
        )
      covered_modules(source_directory, prefix, rest, [
        module,
        ..accumulated_reversed
      ])
    }
  }
}

/// The BEAM module name of a file, from its path relative to the source
/// directory. Gleam: `/` becomes `@` (`app/cart.gleam` is `app@cart`).
/// Erlang: the file name without its extension.
fn module_name(prefix: List(String), relative_path: String) -> String {
  case string.ends_with(relative_path, ".erl") {
    True -> erlang_module_name(relative_path)
    False -> gleam_module_name(prefix, relative_path)
  }
}

fn gleam_module_name(prefix: List(String), relative_path: String) -> String {
  let module_path =
    relative_path
    |> string.drop_end(string.length(".gleam"))
    |> string.split("/")
  string.join(list.append(prefix, module_path), "@")
}

fn erlang_module_name(relative_path: String) -> String {
  relative_path
  |> base_name()
  |> string.drop_end(string.length(".erl"))
}

/// Read the call counts, build the report, and write the LCOV file.
///
/// Call this after the code you want to measure has run. `runner.coverage`
/// does this for you.
///
/// ## Parameters
///
/// - `session`: the session that `coverage.start` returned
///
/// ## Returns
///
/// - `Ok(CoverageReport)` with one file per measured module (plus any file
///   from `coverage.merge_lcov` that is not excluded), sorted by path
/// - `Error(CoverageError)` when a module cannot be analysed, an LCOV file to
///   merge cannot be read, a file that only merged LCOV covers has a bad
///   ignore marker, or the LCOV file cannot be written
///
/// ## Example
///
/// ```gleam
/// let assert Ok(session) = coverage.start(coverage.new())
/// run_my_tests()
/// let assert Ok(coverage_report) = coverage.finish(session)
/// ```
pub fn finish(
  session session: CoverageSession,
) -> Result(CoverageReport, CoverageError) {
  case analyse_modules(session.modules, []) {
    Ok(files) -> merge_then_write(files, session)
    Error(error) -> Error(error)
  }
}

fn merge_then_write(
  files: List(FileCoverage),
  session: CoverageSession,
) -> Result(CoverageReport, CoverageError) {
  let counts = list.fold(files, dict.new(), add_file_counts)
  case merge_patterns(session.config.merge_lcov_patterns, counts) {
    Ok(merged) ->
      merged
      |> dict.drop(session.excluded_paths)
      |> ignore_then_write(session)
    Error(error) -> Error(error)
  }
}

/// Drop the ignored lines, then build the report and write the LCOV file.
/// Files that only merged LCOV covers have their markers read here.
fn ignore_then_write(
  counts: Counts,
  session: CoverageSession,
) -> Result(CoverageReport, CoverageError) {
  case add_ignored_lines(session.ignored_lines, dict.keys(counts)) {
    Ok(ignored_lines) ->
      counts
      |> dict.to_list()
      |> without_ignored_lines(ignored_lines, dict.new())
      |> report_from_counts()
      |> write_report(session.config.lcov_path)
    Error(error) -> Error(error)
  }
}

fn without_ignored_lines(
  entries: List(#(String, Dict(Int, Int))),
  ignored_lines: IgnoredLines,
  accumulated: Counts,
) -> Counts {
  case entries {
    [] -> accumulated
    [#(source_path, file_counts), ..rest] -> {
      let file_ignored_lines =
        result.unwrap(dict.get(ignored_lines, source_path), dict.new())
      let kept_counts = dict.drop(file_counts, dict.keys(file_ignored_lines))
      without_ignored_lines(
        rest,
        ignored_lines,
        dict.insert(accumulated, source_path, kept_counts),
      )
    }
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
  case analyse_module(module.module_name, module.source_path) {
    Ok(lines) -> {
      let file_coverage = report.file(module.source_path, lines)
      analyse_modules(rest, [file_coverage, ..accumulated_reversed])
    }
    Error(error) -> Error(error)
  }
}

fn write_report(
  coverage_report: CoverageReport,
  lcov_path: Option(String),
) -> Result(CoverageReport, CoverageError) {
  case lcov_path {
    None -> Ok(coverage_report)
    Some(path) -> write_report_to(coverage_report, path)
  }
}

fn write_report_to(
  coverage_report: CoverageReport,
  path: String,
) -> Result(CoverageReport, CoverageError) {
  case file.write(path, render_lcov(coverage_report)) {
    Ok(Nil) -> Ok(coverage_report)
    Error(error) -> Error(LcovWriteFailed(path: path, error: error))
  }
}

// =============================================================================
// Ignore markers
// =============================================================================

/// The lines that ignore markers leave out of coverage, per source path.
/// Each line maps to the text written after its marker (empty when there is
/// none).
type IgnoredLines =
  Dict(String, Dict(Int, String))

/// How comments start in a source file.
type CommentSyntax {
  GleamComments
  ErlangComments
}

/// What one line of a source file is, for the ignore markers.
type SourceLine {
  Marker(kind: MarkerKind, text: String)
  CodeLine
  OtherLine
}

type MarkerKind {
  IgnoreLine
  IgnoreStart
  IgnoreEnd
  IgnoreFunction
}

/// An ignore-start marker that has no ignore-end marker yet.
type OpenBlock {
  OpenBlock(line_number: Int, text: String)
}

/// Where the marker reader is in one source file, and what it found.
type MarkerScan {
  MarkerScan(
    source_path: String,
    syntax: CommentSyntax,
    line_number: Int,
    ignored: Dict(Int, String),
    open_block: Option(OpenBlock),
    pending_text: Option(String),
  )
}

/// Read the markers of each path that `ignored_lines` does not hold yet.
fn add_ignored_lines(
  ignored_lines: IgnoredLines,
  source_paths: List(String),
) -> Result(IgnoredLines, CoverageError) {
  case source_paths {
    [] -> Ok(ignored_lines)
    [source_path, ..rest] ->
      add_file_ignored_lines(ignored_lines, source_path, rest)
  }
}

fn add_file_ignored_lines(
  ignored_lines: IgnoredLines,
  source_path: String,
  rest: List(String),
) -> Result(IgnoredLines, CoverageError) {
  case dict.has_key(ignored_lines, source_path) {
    True -> add_ignored_lines(ignored_lines, rest)
    False -> read_file_ignored_lines(ignored_lines, source_path, rest)
  }
}

fn read_file_ignored_lines(
  ignored_lines: IgnoredLines,
  source_path: String,
  rest: List(String),
) -> Result(IgnoredLines, CoverageError) {
  case file.read(source_path) {
    Ok(text) ->
      scan_then_continue(
        ignored_lines,
        source_path,
        string.split(text, "\n"),
        rest,
      )
    Error(error) -> Error(SourceReadFailed(path: source_path, error: error))
  }
}

fn scan_then_continue(
  ignored_lines: IgnoredLines,
  source_path: String,
  lines: List(String),
  rest: List(String),
) -> Result(IgnoredLines, CoverageError) {
  let scan =
    MarkerScan(
      source_path: source_path,
      syntax: comment_syntax(source_path),
      line_number: 1,
      ignored: dict.new(),
      open_block: None,
      pending_text: None,
    )
  case scan_lines(scan, lines) {
    Ok(ignored) ->
      add_ignored_lines(dict.insert(ignored_lines, source_path, ignored), rest)
    Error(error) -> Error(error)
  }
}

/// `.erl` files use `%` comments. Every other file uses `//` comments.
fn comment_syntax(source_path: String) -> CommentSyntax {
  case string.ends_with(source_path, ".erl") {
    True -> ErlangComments
    False -> GleamComments
  }
}

fn scan_lines(
  scan: MarkerScan,
  lines: List(String),
) -> Result(Dict(Int, String), CoverageError) {
  case lines, scan.open_block {
    [], None -> Ok(scan.ignored)
    [], Some(open) ->
      Error(IgnoreStartWithoutEnd(
        source_path: scan.source_path,
        line_number: open.line_number,
      ))
    [line, ..rest], _ -> scan_line_then_continue(scan, line, rest)
  }
}

fn scan_line_then_continue(
  scan: MarkerScan,
  line: String,
  rest: List(String),
) -> Result(Dict(Int, String), CoverageError) {
  case classify_line(scan.syntax, line), scan.open_block, scan.pending_text {
    Marker(IgnoreStart, _), Some(open), _ ->
      Error(NestedIgnoreStart(
        source_path: scan.source_path,
        line_number: scan.line_number,
        open_line_number: open.line_number,
      ))
    Marker(IgnoreStart, text), None, _ ->
      MarkerScan(
        ..ignore_line(scan, text),
        open_block: Some(OpenBlock(line_number: scan.line_number, text: text)),
        pending_text: None,
      )
      |> next_line(rest)
    Marker(IgnoreEnd, _), None, _ ->
      Error(IgnoreEndWithoutStart(
        source_path: scan.source_path,
        line_number: scan.line_number,
      ))
    Marker(IgnoreEnd, _), Some(open), _ ->
      MarkerScan(..ignore_line(scan, open.text), open_block: None)
      |> next_line(rest)
    _, Some(open), _ -> next_line(ignore_line(scan, open.text), rest)
    Marker(IgnoreFunction, text), None, _ ->
      ignore_function_then_continue(scan, text, rest)
    Marker(IgnoreLine, text), None, _ ->
      next_line(MarkerScan(..scan, pending_text: Some(text)), rest)
    CodeLine, None, Some(text) ->
      MarkerScan(..ignore_line(scan, text), pending_text: None)
      |> next_line(rest)
    CodeLine, None, None -> next_line(scan, rest)
    OtherLine, None, _ -> next_line(scan, rest)
  }
}

fn next_line(
  scan: MarkerScan,
  rest: List(String),
) -> Result(Dict(Int, String), CoverageError) {
  scan_lines(MarkerScan(..scan, line_number: scan.line_number + 1), rest)
}

fn ignore_line(scan: MarkerScan, text: String) -> MarkerScan {
  MarkerScan(..scan, ignored: dict.insert(scan.ignored, scan.line_number, text))
}

fn classify_line(syntax: CommentSyntax, line: String) -> SourceLine {
  case syntax, string.trim(line) {
    _, "" -> OtherLine
    GleamComments, "///" <> _ -> OtherLine
    GleamComments, "//" <> body -> comment_line(body)
    ErlangComments, "%" <> body -> comment_line(without_leading_percents(body))
    _, _ -> CodeLine
  }
}

fn without_leading_percents(text: String) -> String {
  case text {
    "%" <> rest -> without_leading_percents(rest)
    _ -> text
  }
}

/// A comment is a marker when its first word is a marker name. The rest of
/// the comment is the marker's text.
fn comment_line(body: String) -> SourceLine {
  let words =
    body
    |> string.replace("\t", " ")
    |> string.trim()
    |> string.split_once(" ")
  case words {
    Ok(#(word, text)) -> marker_line(word, string.trim(text))
    Error(Nil) -> marker_line(string.trim(body), "")
  }
}

fn marker_line(word: String, text: String) -> SourceLine {
  case word {
    "coverage:ignore" -> Marker(kind: IgnoreLine, text: text)
    "coverage:ignore-start" -> Marker(kind: IgnoreStart, text: text)
    "coverage:ignore-end" -> Marker(kind: IgnoreEnd, text: text)
    "coverage:ignore-function" -> Marker(kind: IgnoreFunction, text: text)
    _ -> OtherLine
  }
}

// =============================================================================
// Function markers
// =============================================================================

/// Where the function reader is: the source text that is left, and the line
/// that this text starts on. Line 1 is the line after the marker.
type Cursor {
  Cursor(text: String, line: Int)
}

/// One token of source code. The reader skips white space, comments, strings
/// and Erlang character literals, so a brace or a dot in them is never a
/// token.
type Token {
  Token(kind: TokenKind, line: Int)
}

type TokenKind {
  Word(String)
  Symbol(String)
  /// The Erlang `.` that ends a form: a dot before white space, a comment or
  /// the end of the text.
  FormEnd
  EndOfText
}

/// Ignore the marker line and every line of the function after it, then go
/// on from the line after the function.
fn ignore_function_then_continue(
  scan: MarkerScan,
  text: String,
  rest: List(String),
) -> Result(Dict(Int, String), CoverageError) {
  let source =
    rest
    |> string.join("\n")
    |> string.replace("\r", "")
  case function_last_line(scan.syntax, Cursor(text: source, line: 1)) {
    Ok(offset) ->
      MarkerScan(..scan, pending_text: None)
      |> ignore_range(scan.line_number + offset, text)
      |> next_line(list.drop(rest, offset))
    Error(Nil) ->
      Error(IgnoreFunctionWithoutFunction(
        source_path: scan.source_path,
        line_number: scan.line_number,
      ))
  }
}

/// Ignore every line from the scan's line to `last_line`. The scan stays on
/// `last_line`.
fn ignore_range(scan: MarkerScan, last_line: Int, text: String) -> MarkerScan {
  let ignored = ignore_line(scan, text)
  case scan.line_number < last_line {
    True ->
      ignore_range(
        MarkerScan(..ignored, line_number: scan.line_number + 1),
        last_line,
        text,
      )
    False -> ignored
  }
}

/// The line, counted from the cursor, where the function after a
/// `coverage:ignore-function` marker ends. `Error(Nil)` when the code after
/// the marker is not a complete function.
fn function_last_line(
  syntax: CommentSyntax,
  cursor: Cursor,
) -> Result(Int, Nil) {
  case syntax {
    GleamComments -> gleam_function_last_line(cursor)
    ErlangComments -> erlang_function_last_line(cursor)
  }
}

/// Skip attributes such as `@external(...)` and `@deprecated(...)`, then
/// read a `fn` or `pub fn` up to its parameters.
fn gleam_function_last_line(cursor: Cursor) -> Result(Int, Nil) {
  let #(first, after_first) = next_token(GleamComments, cursor)
  let #(second, after_second) = next_token(GleamComments, after_first)
  case first.kind, second.kind {
    Symbol("@"), Word(_) ->
      gleam_function_last_line(after_attribute_arguments(after_second))
    Word("pub"), Word("fn") ->
      gleam_after_parameters(read_to_close(after_second, "(", ")", -1))
    Word("fn"), _ ->
      gleam_after_parameters(read_to_close(after_first, "(", ")", -1))
    _, _ -> Error(Nil)
  }
}

fn after_attribute_arguments(cursor: Cursor) -> Cursor {
  let #(token, after) = next_token(GleamComments, cursor)
  case token.kind {
    Symbol("(") -> read_to_close(after, "(", ")", 0).1
    _ -> cursor
  }
}

/// Read tokens up to the bracket that closes at `depth` 0. Each `open`
/// adds 1 to the depth and each `close` takes 1 away, so a start depth of
/// -1 reads past the first `open` too. Returns the closing token, or the
/// end-of-text token when the bracket never closes.
fn read_to_close(
  cursor: Cursor,
  open: String,
  close: String,
  depth: Int,
) -> #(Token, Cursor) {
  let #(token, after) = next_token(GleamComments, cursor)
  case token.kind {
    EndOfText -> #(token, after)
    Symbol(symbol) if symbol == close && depth == 0 -> #(token, after)
    Symbol(symbol) if symbol == close ->
      read_to_close(after, open, close, depth - 1)
    Symbol(symbol) if symbol == open ->
      read_to_close(after, open, close, depth + 1)
    _ -> read_to_close(after, open, close, depth)
  }
}

fn gleam_after_parameters(close: #(Token, Cursor)) -> Result(Int, Nil) {
  case close.0.kind {
    EndOfText -> Error(Nil)
    _ -> gleam_return_type_last_line(close.1, close.0.line)
  }
}

/// Read the return type, if there is one, then the body in braces. An
/// external function has no body: it ends at the last token of its return
/// type, or at its parameters.
fn gleam_return_type_last_line(
  cursor: Cursor,
  last_line: Int,
) -> Result(Int, Nil) {
  let #(token, after) = next_token(GleamComments, cursor)
  let #(following, _) = next_token(GleamComments, after)
  case token.kind, following.kind {
    Symbol("{"), _ -> closing_line(read_to_close(after, "{", "}", 0))
    Word("fn"), Symbol("(") -> gleam_return_type_last_line(after, token.line)
    Word("pub"), _
    | Word("fn"), _
    | Word("type"), _
    | Word("const"), _
    | Word("import"), _
    -> Ok(last_line)
    Word(_), _
    | Symbol("->"), _
    | Symbol("."), _
    | Symbol(","), _
    | Symbol("#"), _
    | Symbol("("), _
    | Symbol(")"), _
    -> gleam_return_type_last_line(after, token.line)
    _, _ -> Ok(last_line)
  }
}

fn closing_line(close: #(Token, Cursor)) -> Result(Int, Nil) {
  case close.0.kind {
    EndOfText -> Error(Nil)
    _ -> Ok(close.0.line)
  }
}

/// Skip attributes such as `-spec` and `-doc`, then read the function to the
/// dot that ends its last clause.
fn erlang_function_last_line(cursor: Cursor) -> Result(Int, Nil) {
  let #(first, after_first) = next_token(ErlangComments, cursor)
  let #(second, _) = next_token(ErlangComments, after_first)
  case first.kind, second.kind {
    Symbol("-"), _ -> erlang_function_last_line(read_form(after_first).1)
    Word(_), Symbol("(") -> erlang_form_last_line(read_form(after_first))
    _, _ -> Error(Nil)
  }
}

/// Read tokens up to the end of the form, or to the end of the text.
fn read_form(cursor: Cursor) -> #(Token, Cursor) {
  let #(token, after) = next_token(ErlangComments, cursor)
  case token.kind {
    FormEnd | EndOfText -> #(token, after)
    _ -> read_form(after)
  }
}

fn erlang_form_last_line(form_end: #(Token, Cursor)) -> Result(Int, Nil) {
  case form_end.0.kind {
    FormEnd -> Ok(form_end.0.line)
    _ -> Error(Nil)
  }
}

fn next_token(syntax: CommentSyntax, cursor: Cursor) -> #(Token, Cursor) {
  case syntax, cursor.text {
    _, "" -> #(Token(kind: EndOfText, line: cursor.line), cursor)
    _, "\n" <> rest ->
      next_token(syntax, Cursor(text: rest, line: cursor.line + 1))
    _, " " <> rest | _, "\t" <> rest ->
      next_token(syntax, Cursor(..cursor, text: rest))
    GleamComments, "//" <> rest | ErlangComments, "%" <> rest ->
      next_token(syntax, after_comment(Cursor(..cursor, text: rest)))
    _, "\"" <> rest ->
      next_token(syntax, after_quoted(Cursor(..cursor, text: rest), "\""))
    ErlangComments, "'" <> rest -> #(
      Token(kind: Word("'"), line: cursor.line),
      after_quoted(Cursor(..cursor, text: rest), "'"),
    )
    ErlangComments, "$\\" <> rest | ErlangComments, "$" <> rest ->
      next_token(syntax, after_character(Cursor(..cursor, text: rest)))
    ErlangComments, "." <> rest -> #(
      Token(kind: erlang_dot(rest), line: cursor.line),
      Cursor(..cursor, text: rest),
    )
    GleamComments, "->" <> rest -> #(
      Token(kind: Symbol("->"), line: cursor.line),
      Cursor(..cursor, text: rest),
    )
    _, text -> word_or_symbol(cursor, take_word(syntax, text, ""))
  }
}

fn after_comment(cursor: Cursor) -> Cursor {
  case string.split_once(cursor.text, "\n") {
    Ok(#(_, rest)) -> Cursor(text: rest, line: cursor.line + 1)
    Error(Nil) -> Cursor(..cursor, text: "")
  }
}

/// Skip to the character after the closing `quote`. A backslash escapes the
/// character after it.
fn after_quoted(cursor: Cursor, quote: String) -> Cursor {
  case cursor.text, string.starts_with(cursor.text, quote) {
    _, True -> Cursor(..cursor, text: string.drop_start(cursor.text, 1))
    "", False -> cursor
    "\\" <> rest, False ->
      after_quoted(after_character(Cursor(..cursor, text: rest)), quote)
    _, False -> after_quoted(after_character(cursor), quote)
  }
}

/// Skip one character, and count it when it is a line break.
fn after_character(cursor: Cursor) -> Cursor {
  case cursor.text {
    "\n" <> rest -> Cursor(text: rest, line: cursor.line + 1)
    text -> Cursor(..cursor, text: string.drop_start(text, 1))
  }
}

/// A dot ends an Erlang form when white space, a comment or the end of the
/// text follows it. Other dots are in floats and record fields.
fn erlang_dot(rest: String) -> TokenKind {
  case rest {
    "" | " " <> _ | "\t" <> _ | "\n" <> _ | "%" <> _ -> FormEnd
    _ -> Symbol(".")
  }
}

fn word_or_symbol(cursor: Cursor, word: #(String, String)) -> #(Token, Cursor) {
  case word {
    #("", text) -> #(
      Token(kind: Symbol(string.slice(text, 0, 1)), line: cursor.line),
      Cursor(..cursor, text: string.drop_start(text, 1)),
    )
    #(name, rest) -> #(
      Token(kind: Word(name), line: cursor.line),
      Cursor(..cursor, text: rest),
    )
  }
}

/// Split the text into the word at its start (letters, digits and `_`, and
/// `@` in Erlang) and the text after the word.
fn take_word(
  syntax: CommentSyntax,
  text: String,
  word: String,
) -> #(String, String) {
  let first = string.slice(text, 0, 1)
  case is_word_character(syntax, first) {
    True -> take_word(syntax, string.drop_start(text, 1), word <> first)
    False -> #(word, text)
  }
}

fn is_word_character(syntax: CommentSyntax, character: String) -> Bool {
  case syntax, character {
    _, "_" | ErlangComments, "@" -> True
    _, _ ->
      string.lowercase(character) != string.uppercase(character)
      || result.is_ok(int.parse(character))
  }
}

// =============================================================================
// Merging LCOV
// =============================================================================

/// Call counts per source path, then per line.
type Counts =
  Dict(String, Dict(Int, Int))

/// One `SF` record, with where it starts (for errors about a record that
/// never ends).
type LcovRecord {
  LcovRecord(
    source_path: String,
    lines: List(#(Int, Int)),
    start: LcovPosition,
    start_line: String,
  )
}

/// Where the LCOV reader is: the file and the 1-based line number.
type LcovPosition {
  LcovPosition(path: String, line_number: Int)
}

fn add_file_counts(counts: Counts, file: FileCoverage) -> Counts {
  add_line_counts(
    counts,
    report.source_path(file),
    list.map(report.lines(file), line_pair),
  )
}

fn line_pair(line: LineCoverage) -> #(Int, Int) {
  #(line.line, line.calls)
}

fn add_line_counts(
  counts: Counts,
  source_path: String,
  lines: List(#(Int, Int)),
) -> Counts {
  let file_counts = case dict.get(counts, source_path) {
    Ok(existing) -> existing
    Error(Nil) -> dict.new()
  }
  dict.insert(
    counts,
    source_path,
    list.fold(lines, file_counts, add_line_count),
  )
}

fn add_line_count(file_counts: Dict(Int, Int), line: #(Int, Int)) {
  let #(line_number, calls) = line
  let existing = case dict.get(file_counts, line_number) {
    Ok(existing) -> existing
    Error(Nil) -> 0
  }
  dict.insert(file_counts, line_number, existing + calls)
}

fn report_from_counts(counts: Counts) -> CoverageReport {
  counts
  |> dict.to_list()
  |> list.sort(compare_paths)
  |> list.map(file_from_counts)
  |> report.new()
}

fn compare_paths(
  left: #(String, Dict(Int, Int)),
  right: #(String, Dict(Int, Int)),
) -> Order {
  string.compare(left.0, right.0)
}

fn file_from_counts(entry: #(String, Dict(Int, Int))) -> FileCoverage {
  let #(source_path, file_counts) = entry
  report.file(source_path, list.map(dict.to_list(file_counts), line_from_pair))
}

fn line_from_pair(pair: #(Int, Int)) -> LineCoverage {
  LineCoverage(line: pair.0, calls: pair.1)
}

fn merge_patterns(
  patterns: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case patterns {
    [] -> Ok(counts)
    [pattern, ..rest] -> merge_pattern_then_continue(pattern, rest, counts)
  }
}

fn merge_pattern_then_continue(
  pattern: String,
  rest: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case match_files(pattern) {
    [] -> Error(NoLcovFilesMatched(pattern: pattern))
    paths -> merge_files_then_patterns(paths, rest, counts)
  }
}

fn merge_files_then_patterns(
  paths: List(String),
  patterns: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case merge_lcov_files(paths, counts) {
    Ok(merged) -> merge_patterns(patterns, merged)
    Error(error) -> Error(error)
  }
}

fn merge_lcov_files(
  paths: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case paths {
    [] -> Ok(counts)
    [path, ..rest] -> merge_lcov_file_then_continue(path, rest, counts)
  }
}

fn merge_lcov_file_then_continue(
  path: String,
  rest: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case read_lcov_records(path) {
    Ok(records) -> merge_records_then_files(records, path, rest, counts)
    Error(error) -> Error(error)
  }
}

fn merge_records_then_files(
  records: List(LcovRecord),
  path: String,
  rest: List(String),
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case add_records(records, path, counts) {
    Ok(merged) -> merge_lcov_files(rest, merged)
    Error(error) -> Error(error)
  }
}

fn add_records(
  records: List(LcovRecord),
  path: String,
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case records {
    [] -> Ok(counts)
    [record, ..rest] -> add_record_then_continue(record, rest, path, counts)
  }
}

fn add_record_then_continue(
  record: LcovRecord,
  rest: List(LcovRecord),
  path: String,
  counts: Counts,
) -> Result(Counts, CoverageError) {
  case is_regular_file(record.source_path) {
    True ->
      add_records(
        rest,
        path,
        add_line_counts(counts, record.source_path, record.lines),
      )
    False ->
      Error(LcovSourceNotFound(lcov_path: path, source_path: record.source_path))
  }
}

fn read_lcov_records(path: String) -> Result(List(LcovRecord), CoverageError) {
  case file.read(path) {
    Ok(text) ->
      parse_lcov_lines(
        string.split(text, "\n"),
        LcovPosition(path: path, line_number: 1),
        None,
        [],
      )
    Error(error) -> Error(LcovReadFailed(path: path, error: error))
  }
}

fn parse_lcov_lines(
  lines: List(String),
  position: LcovPosition,
  open_record: Option(LcovRecord),
  records_reversed: List(LcovRecord),
) -> Result(List(LcovRecord), CoverageError) {
  case lines, open_record {
    [], None -> Ok(list.reverse(records_reversed))
    [], Some(record) ->
      malformed(
        record.start,
        record.start_line,
        "this record never ends; every SF record must end with end_of_record.",
      )
    [line, ..rest], _ ->
      parse_lcov_line(
        string.trim_end(line),
        rest,
        position,
        open_record,
        records_reversed,
      )
  }
}

fn parse_lcov_line(
  line: String,
  rest: List(String),
  position: LcovPosition,
  open_record: Option(LcovRecord),
  records_reversed: List(LcovRecord),
) -> Result(List(LcovRecord), CoverageError) {
  let next = LcovPosition(..position, line_number: position.line_number + 1)
  case line, open_record {
    "", _ -> parse_lcov_lines(rest, next, open_record, records_reversed)
    "SF:" <> source_path, None if source_path != "" ->
      parse_lcov_lines(
        rest,
        next,
        Some(LcovRecord(
          source_path: source_path,
          lines: [],
          start: position,
          start_line: line,
        )),
        records_reversed,
      )
    "SF:" <> _, None ->
      malformed(position, line, "SF must be followed by a source file path.")
    "SF:" <> _, Some(_) ->
      malformed(
        position,
        line,
        "a new SF record starts before the previous one ends with end_of_record.",
      )
    "DA:" <> fields, Some(record) ->
      parse_da_line(fields, line, rest, position, record, records_reversed)
    "DA:" <> _, None ->
      malformed(
        position,
        line,
        "DA appears outside a record (no SF line before it).",
      )
    "end_of_record", Some(record) ->
      parse_lcov_lines(rest, next, None, [record, ..records_reversed])
    "end_of_record", None ->
      malformed(
        position,
        line,
        "end_of_record appears without an SF line before it.",
      )
    _, _ ->
      parse_other_line(line, rest, position, open_record, records_reversed)
  }
}

fn parse_other_line(
  line: String,
  rest: List(String),
  position: LcovPosition,
  open_record: Option(LcovRecord),
  records_reversed: List(LcovRecord),
) -> Result(List(LcovRecord), CoverageError) {
  case starts_with_any(line, ignored_lcov_prefixes) {
    True ->
      parse_lcov_lines(
        rest,
        LcovPosition(..position, line_number: position.line_number + 1),
        open_record,
        records_reversed,
      )
    False ->
      malformed(
        position,
        line,
        "this is not an LCOV line; LCOV lines start with TN:, SF:, DA:, LF:, LH:, FN:, FNDA:, FNF:, FNH:, BRDA:, BRF:, BRH: or VER:, or are end_of_record.",
      )
  }
}

/// LCOV lines that are valid but carry nothing line coverage needs: `LF` and
/// `LH` are recomputed from the `DA` lines, and function and branch records
/// are not measured.
const ignored_lcov_prefixes = [
  "TN:", "LF:", "LH:", "FN:", "FNDA:", "FNF:", "FNH:", "BRDA:", "BRF:", "BRH:",
  "VER:",
]

fn starts_with_any(line: String, prefixes: List(String)) -> Bool {
  case prefixes {
    [] -> False
    [prefix, ..rest] ->
      string.starts_with(line, prefix) || starts_with_any(line, rest)
  }
}

fn parse_da_line(
  fields: String,
  line: String,
  rest: List(String),
  position: LcovPosition,
  record: LcovRecord,
  records_reversed: List(LcovRecord),
) -> Result(List(LcovRecord), CoverageError) {
  case parse_da_fields(string.split(fields, ",")) {
    Ok(pair) ->
      parse_lcov_lines(
        rest,
        LcovPosition(..position, line_number: position.line_number + 1),
        Some(LcovRecord(..record, lines: [pair, ..record.lines])),
        records_reversed,
      )
    Error(Nil) ->
      malformed(
        position,
        line,
        "DA must be DA:line,count (with an optional checksum), where line is 1 or more and count is 0 or more.",
      )
  }
}

fn parse_da_fields(fields: List(String)) -> Result(#(Int, Int), Nil) {
  case fields {
    [line_number, calls] -> da_numbers(int.parse(line_number), int.parse(calls))
    [line_number, calls, _checksum] ->
      da_numbers(int.parse(line_number), int.parse(calls))
    _ -> Error(Nil)
  }
}

fn da_numbers(
  line_number: Result(Int, Nil),
  calls: Result(Int, Nil),
) -> Result(#(Int, Int), Nil) {
  case line_number, calls {
    Ok(line_number), Ok(calls) if line_number >= 1 && calls >= 0 ->
      Ok(#(line_number, calls))
    _, _ -> Error(Nil)
  }
}

fn malformed(
  position: LcovPosition,
  line: String,
  problem: String,
) -> Result(a, CoverageError) {
  Error(MalformedLcov(
    path: position.path,
    line_number: position.line_number,
    line: line,
    problem: problem,
  ))
}

/// LCOV: per file `SF`, one `DA:line,calls` per executable line, `LF` (lines
/// found), `LH` (lines hit) and `end_of_record`.
fn render_lcov(coverage_report: CoverageReport) -> String {
  coverage_report
  |> report.files()
  |> list.map(render_lcov_record)
  |> string.concat()
}

fn render_lcov_record(file: FileCoverage) -> String {
  "TN:\nSF:"
  <> report.source_path(file)
  <> "\n"
  <> string.concat(list.map(report.lines(file), render_lcov_line))
  <> "LF:"
  <> int.to_string(report.executable_line_count(file))
  <> "\nLH:"
  <> int.to_string(report.hit_line_count(file))
  <> "\nend_of_record\n"
}

fn render_lcov_line(line: LineCoverage) -> String {
  "DA:" <> int.to_string(line.line) <> "," <> int.to_string(line.calls) <> "\n"
}

/// Check total coverage against `coverage.minimum_percent`.
///
/// Passes when no minimum is set, when there are no executable lines, or
/// when `hit / total` is equal to the minimum or above it. The comparison is
/// exact and uses the minimum rounded to one decimal place.
///
/// ## Parameters
///
/// - `config`: the settings that hold the minimum
/// - `report`: the report to check
///
/// ## Returns
///
/// - `Ok(Nil)` when coverage meets the minimum
/// - `Error(BelowMinimumPercent(..))` when it does not
/// - `Error(InvalidMinimumPercent(..))` when the minimum is not from 0.0 to
///   100.0
///
/// ## Example
///
/// ```gleam
/// coverage.new()
/// |> coverage.minimum_percent(80.0)
/// |> coverage.check_minimum(coverage_report)
/// // -> Error(BelowMinimumPercent(hit: 1567, total: 2230,
/// //      minimum_percent: 80.0, lines_needed: 1784))
/// ```
pub fn check_minimum(
  config config: CoverageConfig,
  report coverage_report: CoverageReport,
) -> Result(Nil, CoverageError) {
  case
    config.minimum_percent,
    validate_minimum_percent(config.minimum_percent)
  {
    None, _ -> Ok(Nil)
    _, Error(error) -> Error(error)
    Some(minimum), Ok(Nil) ->
      check_counts_against_minimum(
        report.total_hit_line_count(coverage_report),
        report.total_executable_line_count(coverage_report),
        round(minimum *. 10.0),
      )
  }
}

fn check_counts_against_minimum(
  hit: Int,
  total: Int,
  minimum_tenths: Int,
) -> Result(Nil, CoverageError) {
  case hit * 1000 >= minimum_tenths * total {
    True -> Ok(Nil)
    False ->
      Error(BelowMinimumPercent(
        hit: hit,
        total: total,
        minimum_percent: int.to_float(minimum_tenths) /. 10.0,
        lines_needed: { minimum_tenths * total + 999 } / 1000,
      ))
  }
}

// =============================================================================
// Erlang
// =============================================================================

@external(erlang, "erlang", "round")
fn round(value: Float) -> Int

@external(erlang, "dream_test_coverage_ffi", "start_cover")
fn start_cover() -> Result(Nil, CoverageError)

@external(erlang, "dream_test_coverage_ffi", "list_source_files")
fn list_source_files(directory: String) -> Result(List(String), CoverageError)

@external(erlang, "dream_test_coverage_ffi", "compile_module")
fn compile_module(
  module_name: String,
  source_path: String,
) -> Result(Nil, CoverageError)

@external(erlang, "dream_test_coverage_ffi", "analyse_module")
fn analyse_module(
  module_name: String,
  source_path: String,
) -> Result(List(LineCoverage), CoverageError)

@external(erlang, "dream_test_coverage_ffi", "match_files")
fn match_files(pattern: String) -> List(String)

@external(erlang, "dream_test_coverage_ffi", "is_regular_file")
fn is_regular_file(path: String) -> Bool

@external(erlang, "filename", "basename")
fn base_name(path: String) -> String
