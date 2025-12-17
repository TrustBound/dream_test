//// Feature discovery and loading for Gherkin tests.
////
//// Provides a builder pattern for discovering `.feature` files and
//// converting them to TestSuites without manual file parsing.
////
//// ## Terminology: step registry
////
//// Gherkin scenarios contain steps like “Given …”, “When …”, “Then …”.
//// A **step registry** (`steps.StepRegistry`) is the collection of step
//// definitions that tell Dream Test how to execute those steps:
////
//// - you create it with `dream_test/gherkin/steps.new_registry()`
//// - you add step definitions with `given`, `when_`, `then_`, or `step`
////
//// Discovery needs a registry only when converting features into runnable
//// suites (`to_suite`), because the suite’s tests must be able to *execute*
//// steps. Pure parsing (`load`) does not.
////
//// ## Example
////
//// ```gleam
//// import dream_test/gherkin/discover
//// import dream_test/gherkin/steps
//// import dream_test/reporter/api as reporter
//// import dream_test/runner
//// import gleam/io
////
//// let registry = steps.new_registry()
//// // |> steps.given("...", handler)
////
//// let suite =
////   discover.features("test/features/**/*.feature")
////   |> discover.with_registry(registry)
////   |> discover.to_suite("Features")
////
//// runner.new([suite])
//// |> runner.reporter(reporter.bdd(io.print, True))
//// |> runner.exit_on_failure()
//// |> runner.run()
//// ```

import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{
  type AssertionResult, type TestSuite, type TestSuiteItem, AssertionFailed,
  AssertionFailure, SuiteGroup, SuiteTest, SuiteTestCase, TestSuite, Unit,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

// ============================================================================
// Types
// ============================================================================

/// Builder for discovering and loading feature files.
///
/// Use `features()` to create, then chain with `with_registry()` and
/// `to_suite()` to build a TestSuite.
///
/// This is opaque so callers can’t depend on internal fields that may change.
pub opaque type FeatureDiscovery {
  FeatureDiscovery(
    /// Glob pattern for finding feature files
    pattern: String,
    /// Step registry (set via with_registry)
    registry: Option(StepRegistry),
    /// Parsed features (populated during to_suite)
    features: List(gherkin_types.Feature),
    /// Parse errors encountered
    errors: List(String),
  )
}

/// Result of loading features, containing both successes and errors.
///
/// This is useful if you want to control how parse errors are handled rather
/// than converting them to failing tests.
pub type LoadResult {
  LoadResult(features: List(gherkin_types.Feature), errors: List(String))
}

// ============================================================================
// Builder API
// ============================================================================

/// Start discovering features matching a glob pattern.
///
/// Use Erlang’s `filelib:wildcard/1` semantics (see `wildcard/1` below).
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/discover
///
/// let discovery = discover.features("test/features/**/*.feature")
/// ```
pub fn features(pattern: String) -> FeatureDiscovery {
  FeatureDiscovery(pattern: pattern, registry: None, features: [], errors: [])
}

/// Attach a step registry to the discovery.
///
/// The step registry is the set of step definitions (Given/When/Then handlers)
/// used to execute scenarios. It is required before calling `to_suite`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/discover
/// import dream_test/gherkin/steps
///
/// let discovery =
///   discover.features("test/features/**/*.feature")
///   |> discover.with_registry(steps.new_registry())
/// ```
pub fn with_registry(
  discovery: FeatureDiscovery,
  registry: StepRegistry,
) -> FeatureDiscovery {
  FeatureDiscovery(..discovery, registry: Some(registry))
}

/// Build a TestSuite from discovered features.
///
/// Panics if `with_registry()` was not called.
///
/// Parse errors are converted into failing unit tests tagged with
/// `"parse-error"`.
///
/// ## What does this produce?
///
/// The returned suite contains one test per scenario. Each test runs the
/// scenario’s steps using the provided step registry.
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/discover
/// import dream_test/gherkin/steps
///
/// let suite =
///   discover.features("test/features/**/*.feature")
///   |> discover.with_registry(steps.new_registry())
///   |> discover.to_suite("Features")
/// ```
pub fn to_suite(
  discovery: FeatureDiscovery,
  suite_name: String,
) -> TestSuite(Nil) {
  let registry = case discovery.registry {
    Some(r) -> r
    None ->
      panic as "FeatureDiscovery requires a registry. Call with_registry() first."
  }

  let files = discover_files(discovery.pattern)
  let load_result = load_all_features(files)

  let suite_items =
    list.map(load_result.features, fn(feature) {
      let config = FeatureConfig(feature: feature, step_registry: registry)
      let feature_suite = to_test_suite(suite_name, config)
      SuiteGroup(feature_suite)
    })

  let error_items = list.map(load_result.errors, error_to_suite_item)
  let all_items = list.append(suite_items, error_items)

  TestSuite(
    name: suite_name,
    before_all: Some(fn() { Ok(Nil) }),
    has_user_before_all: False,
    after_all: [],
    before_each: [],
    after_each: [],
    items: all_items,
  )
}

/// Load features and return detailed results.
///
/// This does **not** require a step registry because it only discovers files
/// and parses Gherkin syntax. Step definitions are only needed when you want to
/// execute scenarios (`to_suite`).
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/discover
///
/// let result = discover.features("test/features/**/*.feature") |> discover.load()
/// ```
pub fn load(discovery: FeatureDiscovery) -> LoadResult {
  let files = discover_files(discovery.pattern)
  load_all_features(files)
}

/// Get the list of files matching the discovery pattern.
///
/// This is a pure discovery step; files are not parsed.
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/discover
///
/// let files = discover.features("test/features/**/*.feature") |> discover.list_files()
/// ```
pub fn list_files(discovery: FeatureDiscovery) -> List(String) {
  discover_files(discovery.pattern)
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn discover_files(pattern: String) -> List(String) {
  wildcard(pattern)
}

fn load_all_features(files: List(String)) -> LoadResult {
  let results = list.map(files, parse_feature_file)

  let features =
    results
    |> list.filter_map(fn(r) {
      case r {
        Ok(f) -> Ok(f)
        Error(_) -> Error(Nil)
      }
    })

  let errors =
    results
    |> list.filter_map(fn(r) {
      case r {
        Ok(_) -> Error(Nil)
        Error(e) -> Ok(e)
      }
    })

  LoadResult(features: features, errors: errors)
}

fn parse_feature_file(path: String) -> Result(gherkin_types.Feature, String) {
  parser.parse_file(path)
  |> result.map_error(fn(e) { path <> ": " <> e })
}

fn error_to_suite_item(error: String) -> TestSuiteItem(Nil) {
  SuiteTest(SuiteTestCase(
    name: "Parse Error: " <> error,
    tags: ["parse-error"],
    kind: Unit,
    run: fn(_) { Ok(parse_error_assertion()) },
    timeout_ms: None,
  ))
}

fn parse_error_assertion() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "parse",
    message: "Failed to parse feature file (see test name for details)",
    payload: None,
  ))
}

// ============================================================================
// FFI
// ============================================================================

/// Find files matching a glob pattern using Erlang's filelib:wildcard/1.
@external(erlang, "dream_test_gherkin_discover_ffi", "wildcard")
fn wildcard(pattern: String) -> List(String)
