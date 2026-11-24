//// Core types for dream_test.
////
//// This module defines the data structures used throughout the framework.
//// Most users won’t need to construct these values directly—`dream_test/unit`,
//// `dream_test/runner`, and the reporter modules create them for you.
////
//// You *will* want to read this module if you are:
////
//// - writing custom matchers (you’ll work with `MatchResult(a)` and `AssertionFailure`)
//// - building a custom reporter (you’ll consume `TestResult`)
//// - filtering results in CI (you’ll inspect `TestResult.tags`, `TestResult.status`, etc.)
////
//// ## Type Overview
////
//// | Type               | Purpose                                          |
//// |--------------------|--------------------------------------------------|
//// | `Status`           | Test outcome (Passed, Failed, etc.)              |
//// | `TestKind`         | Type of test (Unit, Gherkin)                     |
//// | `TestResult`       | Complete result of running a test                |
//// | `AssertionResult`  | Pass/fail result of an assertion chain           |
//// | `MatchResult(a)`   | Intermediate result during assertion chaining    |
//// | `AssertionFailure` | Details about a failed assertion                 |
////
//// ## For Custom Matcher Authors
////
//// If you're writing custom matchers, you'll work with `MatchResult(a)`:
////
//// ### Write a custom matcher <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/types.{
////   type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
//// }
//// import gleam/int
//// import gleam/option.{Some}
////
//// pub fn be_even(result: MatchResult(Int)) -> MatchResult(Int) {
////   case result {
////     // If already failed, propagate the failure
////     MatchFailed(failure) -> MatchFailed(failure)
////     // Otherwise, check our condition
////     MatchOk(value) -> check_even(value)
////   }
//// }
////
//// fn check_even(value: Int) -> MatchResult(Int) {
////   case value % 2 == 0 {
////     True -> MatchOk(value)
////     False ->
////       MatchFailed(AssertionFailure(
////         operator: "be_even",
////         message: "",
////         payload: Some(CustomMatcherFailure(
////           actual: int.to_string(value),
////           description: "expected an even number",
////         )),
////       ))
////   }
//// }
//// ```
//// =============================================================================
//// Unified tree model (Tree/Node)
//// =============================================================================
////
//// Dream Test compiles all unit/context/gherkin tests into a single tree model
//// that the executor runs.
////
//// - `Tree(context)` holds the initial value and the top-level group:
////   its name, tags and children. The top level is always a group. A
////   suite holds one or more trees.
//// - `Node(context)` represents groups, tests, and lifecycle hooks.
////

import gleam/list
import gleam/option.{type Option}

/// The outcome of a test.
///
/// After a test runs, it has one of these statuses:
///
/// | Status        | Meaning                                           |
/// |---------------|---------------------------------------------------|
/// | `Passed`      | All assertions succeeded                          |
/// | `Failed`      | One or more assertions failed                     |
/// | `Skipped`     | Test was marked to skip (not yet implemented)     |
/// | `Pending`     | Test is a placeholder (not yet implemented)       |
/// | `TimedOut`    | The test body ran past its timeout and was killed |
/// | `SetupFailed` | A lifecycle hook failed; test never ran           |
///
/// ## SetupFailed Explained
///
/// `SetupFailed` means the test body did not run because a lifecycle hook
/// failed first.
///
/// In Dream Test, hooks and test bodies can short-circuit with `Error("message")`.
/// When `before_all` fails, each test of that group becomes `SetupFailed`,
/// also the tests of its child groups.
/// When `before_each` fails, only that test becomes `SetupFailed`.
///
/// ## TimedOut Explained
///
/// `TimedOut` is only for the test body. A hook that runs past its timeout
/// does not give `TimedOut`. A setup hook (`before_each`,
/// `before_each_test`, `before_all` and the suite-level setup hooks) gives
/// `SetupFailed`. A teardown hook (`after_each`, `after_each_test`,
/// `after_all` and the suite-level teardown hooks) gives a
/// `TeardownFailed` in the run report, and the test keeps its status.
///
/// ### Fail a before_all hook <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/status.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/unit.{before_all, describe, it}
///
/// fn connect_to_database() -> Result(Nil, String) {
///   Error("connection refused")
/// }
///
/// pub fn handles_failures() -> TestSuite {
///   describe("Handles failures", [
///     before_all(fn() {
///       case connect_to_database() {
///         Ok(_) -> Ok(Nil)
///         Error(reason) -> Error("Database connection failed: " <> reason)
///       }
///     }),
///     // If before_all fails, these tests are marked SetupFailed (not run)
///     it("test1", fn() { Ok(succeed()) }),
///     it("test2", fn() { Ok(succeed()) }),
///   ])
/// }
/// ```
///
/// The failing hook message is recorded on the `TestResult.failures` list so
/// reporters can display it.
///
pub type Status {
  Passed
  Failed
  Skipped
  Pending
  TimedOut
  SetupFailed
}

/// The kind/category of a test.
///
/// Used to distinguish between different testing styles:
///
/// - `Unit` - every test that is not a Gherkin scenario: the tests of
///   `dream_test/unit` and `dream_test/unit_context`, and the failing tests
///   that discovery makes for its errors
/// - `GherkinScenario(scenario_id:, feature:, rule:)` - Tests from Gherkin features
///   (inline DSL or `.feature` files)
///
pub type TestKind {
  Unit
  /// A Gherkin scenario. `scenario_id` is the id that the steps get in
  /// `StepContext.scenario_id`.
  ///
  /// `feature` is the name of the Feature when the scenario is in the group
  /// of its Feature: the scenarios of `steps.feature_suite`,
  /// `steps.Feature` and `gherkin/discover.to_suite`. It is `None` for
  /// the scenarios of `steps.Scenarios`, which go straight into the
  /// group around them, so no group is their Feature. The reporters print
  /// `Feature: <name>` only from this field.
  ///
  /// `rule` is the name of the Rule group, for example
  /// `Some("Rule: Stock")`, for a scenario inside a Rule, and `None` for a
  /// scenario outside a Rule. The Rule group is the last group of the
  /// result. When `feature` is `Some`, the Feature group is the group
  /// before the Rule group, or the last group outside a Rule.
  GherkinScenario(
    scenario_id: String,
    feature: Option(String),
    rule: Option(String),
  )
}

/// Structured details about why an assertion failed.
///
/// Each variant provides context appropriate to the type of assertion.
/// Reporters use this to format helpful error messages.
///
/// ## Variants
///
/// - `EqualityFailure` - For `equal`/`not_equal` comparisons
/// - `BooleanFailure` - For `be_true`/`be_false`
/// - `OptionFailure` - For `be_some`/`be_none`
/// - `ResultFailure` - For `be_ok`/`be_error`
/// - `CollectionFailure` - For `contain`/`have_length`/`be_empty`
/// - `ComparisonFailure` - For `be_greater_than`/`be_less_than`/etc.
/// - `StringMatchFailure` - For `start_with`/`end_with`/`contain_string`
/// - `SnapshotFailure` - For `match_snapshot` comparisons
/// - `CustomMatcherFailure` - For user-defined matchers
/// - `StepFailure` - For a failure in a Gherkin step: it names the step and
///   holds the payload of the failure inside the step
///
/// The reporters show a line diff in place of `Expected` and `Actual` when
/// either text has more than one line; see `dream_test/reporters/diff`.
///
pub type FailurePayload {
  EqualityFailure(actual: String, expected: String)
  BooleanFailure(actual: Bool, expected: Bool)
  OptionFailure(actual: String, expected_some: Bool)
  ResultFailure(actual: String, expected_ok: Bool)
  CollectionFailure(actual: String, expected: String, operation: String)
  ComparisonFailure(actual: String, expected: String, operator: String)
  StringMatchFailure(actual: String, pattern: String, operation: String)
  SnapshotFailure(
    actual: String,
    expected: String,
    snapshot_path: String,
    is_missing: Bool,
  )
  CustomMatcherFailure(actual: String, description: String)
  /// A Gherkin step failed. The failure is the failure of the step: a
  /// matcher in a `then` step, an `Error` from the step function, an
  /// undefined step, or a crash.
  ///
  /// - `keyword` and `text` are the step as written, for example `"Then"`
  ///   and `"the cart total is 15.00"`. In a row of an Examples table,
  ///   `text` has the values of the row.
  /// - `file` is the path of the `.feature` file, from
  ///   `parser.parse_file`, and `None` for an inline feature or a parsed
  ///   string.
  /// - `line` is the line of the step in the feature text, from the parser,
  ///   and `None` for an inline step.
  /// - `cause` is the payload of the failure inside the step, for example
  ///   `Some(EqualityFailure(..))` for a failed `be_equal`, or `None`.
  StepFailure(
    keyword: String,
    text: String,
    file: Option(String),
    line: Option(Int),
    cause: Option(FailurePayload),
  )
}

/// Complete information about a failed assertion.
///
/// Contains:
///
/// - the matcher/operator name (e.g. `"equal"` or `"be_ok"`)
/// - a user-friendly message (provided by `or_fail_with("...")`)
/// - optional structured payload for rich reporting
///
/// ## Fields
///
/// - `operator` - Name of the matcher that failed (e.g., "equal", "be_some")
/// - `message` - User-provided failure message from `or_fail_with`
/// - `payload` - Optional structured details for rich error reporting
///
pub type AssertionFailure {
  AssertionFailure(
    operator: String,
    message: String,
    payload: Option(FailurePayload),
  )
}

/// The final result of an assertion chain.
///
/// This is the value a test ultimately produces to indicate pass/fail/skip.
///
/// In typical usage, you don’t construct `AssertionResult` directly:
/// - assertion chains produce it
/// - `skip(...)` produces `AssertionSkipped`
/// - `pending(...)` produces `AssertionPending`
///
/// ## Variants
///
/// - `AssertionOk` - The assertion chain passed
/// - `AssertionFailed(failure)` - The assertion chain failed with details
/// - `AssertionSkipped` - The test was skipped (used by `skip` function)
/// - `AssertionPending` - The test has no body yet (used by `pending`). Its
///   status is `Pending`, and the run still passes.
///
/// ## Example
///
/// Most users won't construct this directly. It's returned by `or_fail_with`:
///
/// ### Make an AssertionResult with an assertion chain <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/assertion_result.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn two_plus_three_is_five() -> Result(AssertionResult, String) {
///   2 + 3
///   |> should
///   |> be_equal(5)
///   |> or_fail_with("2 + 3 should equal 5")
/// }
/// ```
///
pub type AssertionResult {
  AssertionOk
  AssertionFailed(AssertionFailure)
  AssertionSkipped
  AssertionPending
}

/// Intermediate result during assertion chaining.
///
/// This type carries a value through a chain of matchers. Each matcher receives
/// a `MatchResult`, checks or transforms the value, and returns a new `MatchResult`.
///
/// ## How Chaining Works
///
/// ### Chain matchers through MatchResult <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/match_result.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import gleam/option.{Some}
///
/// pub fn some_holds_forty_two() -> Result(AssertionResult, String) {
///   Some(42)
///   |> should
///   |> be_some()
///   |> be_equal(42)
///   |> or_fail_with("expected Some(42)")
/// }
/// ```
///
/// If any matcher fails, the `MatchFailed` propagates through the rest of
/// the chain without executing further checks.
///
pub type MatchResult(a) {
  MatchOk(a)
  MatchFailed(AssertionFailure)
}

/// Convert a MatchResult to an AssertionResult.
///
/// This discards the value and returns just the pass/fail status.
/// Used internally by `or_fail_with`.
///
/// ## Parameters
///
/// - `result`: the `MatchResult(a)` you want to collapse into pass/fail
///
/// ## Returns
///
/// - `MatchOk(_)` becomes `AssertionOk`
/// - `MatchFailed(failure)` becomes `AssertionFailed(failure)`
///
/// ## Example
///
/// ### Convert MatchOk to AssertionOk <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/to_assertion_result.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn match_ok_becomes_assertion_ok() -> Result(AssertionResult, String) {
///   types.to_assertion_result(types.MatchOk(1))
///   |> should
///   |> be_equal(types.AssertionOk)
///   |> or_fail_with("expected MatchOk -> AssertionOk")
/// }
/// ```
///
pub fn to_assertion_result(result result: MatchResult(a)) -> AssertionResult {
  case result {
    MatchOk(_) -> AssertionOk
    MatchFailed(failure) -> AssertionFailed(failure)
  }
}

/// Complete result of running a test.
///
/// Contains everything needed to report on a test's outcome.
///
/// ## Fields
///
/// - `name` - The test's own name (from `it`)
/// - `groups` - The names of the `describe` groups around the test, from
///   the outermost group in. Use `full_name(groups, name)` for the
///   complete path.
/// - `status` - Whether the test passed, failed, etc.
/// - `duration_ms` - How long the test took in milliseconds
/// - `tags` - Test tags for filtering
/// - `failures` - List of assertion failures (empty if passed)
/// - `kind` - Type of test (Unit, Gherkin)
///
/// ## Example
///
/// After running suites, the run report has one of these for each test:
///
/// ### Read the test results of a run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/test_result.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type TestResult}
/// import dream_test/unit.{describe, it}
///
/// fn example_suite() -> TestSuite {
///   describe("Example", [it("passes", fn() { Ok(succeed()) })])
/// }
///
/// pub fn read_the_test_results() -> List(TestResult) {
///   runner.new([example_suite()])
///   |> runner.run()
///   |> types.report_tests
/// }
/// ```
///
pub type TestResult {
  TestResult(
    name: String,
    groups: List(String),
    status: Status,
    duration_ms: Int,
    tags: List(String),
    failures: List(AssertionFailure),
    kind: TestKind,
  )
}

/// Lightweight test identity information.
///
/// This is used by the runner for filtering and hook metadata.
///
/// ## Fields
///
/// - `name`: the leaf test name (the `it("...")` label)
/// - `groups`: the names of the groups around the test, from the outermost
///   group in. Use `full_name(groups, name)` for the group path and the
///   test name together (deterministic, good for identifiers).
/// - `tags`: effective tags (includes inherited group tags)
/// - `kind`: `TestKind` (Unit or GherkinScenario(scenario_id:, feature:, rule:))
/// - `source`: best-effort origin string (module name or `.feature` path)
///
/// ### Source behavior
///
/// - Unit discovery uses the **module name**
/// - Gherkin discovery uses the **.feature file path**, also when module
///   discovery finds the Gherkin suite
/// - Manually constructed suites use `None`
pub type TestInfo {
  TestInfo(
    name: String,
    groups: List(String),
    tags: List(String),
    kind: TestKind,
    source: Option(String),
  )
}

/// Suite metadata for runner-level hooks.
///
/// ## Fields
///
/// - `name`: top-level suite/group name
/// - `tests`: deterministic list of `TestInfo` values that will execute
/// - `source`: best-effort origin string (see `TestInfo.source`)
pub type SuiteInfo {
  SuiteInfo(name: String, tests: List(TestInfo), source: Option(String))
}

/// One tree of tests in the unified execution model.
///
/// A `Tree(context)` is one top-level group with its children and one
/// context source. It stores the `initial` context value and the
/// top-level group: its `name`, its `tags`, and its `children` (groups,
/// tests and hooks). The top level is always a group, so a tree cannot be
/// a single test. A suite holds one or more trees.
///
/// ## Example
///
/// ### Build a tree with one test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/tree.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/types
/// import gleam/option.{None}
///
/// pub fn math_tree() -> types.Tree(Nil) {
///   types.Tree(initial: Nil, name: "math", tags: [], children: [
///     types.Test(
///       name: "adds",
///       tags: [],
///       kind: types.Unit,
///       run: types.WithInput(fn(_context) { Ok(types.AssertionOk) }),
///       timeout_ms: None,
///       source: None,
///     ),
///   ])
/// }
/// ```
pub type Tree(context) {
  Tree(
    initial: context,
    name: String,
    tags: List(String),
    children: List(Node(context)),
  )
}

/// A node in the unified test tree: groups, tests, and hooks.
///
/// Most users build these values via `dream_test/unit` or `dream_test/unit_context`.
pub type Node(context) {
  /// A named group containing child nodes.
  Group(name: String, tags: List(String), children: List(Node(context)))

  /// A runnable test leaf.
  Test(
    name: String,
    tags: List(String),
    kind: TestKind,
    run: Callback(context, Result(AssertionResult, String)),
    timeout_ms: Option(Int),
    /// Best-effort origin string for this test (module name or .feature path).
    source: Option(String),
  )

  /// Group-scoped hooks.
  BeforeAll(run: Callback(context, Result(context, String)))
  BeforeEach(run: Callback(context, Result(context, String)))
  AfterEach(run: Callback(context, Result(Nil, String)))
  AfterAll(run: Callback(context, Result(Nil, String)))
}

/// A test body or a hook, in the shape that the user wrote it.
///
/// `dream_test/unit` stores functions with no argument, as `NoInput`.
/// `dream_test/unit_context` stores functions that get the context, as
/// `WithInput`. The runner calls both with `call`, so no adapter function
/// is needed.
///
/// ## Example
///
/// ### Call a NoInput callback <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/callback.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// fn setup() -> Result(Nil, String) {
///   Ok(Nil)
/// }
///
/// pub fn no_input_ignores_the_input() -> Result(AssertionResult, String) {
///   types.call(types.NoInput(setup), Nil)
///   |> should
///   |> be_equal(Ok(Nil))
///   |> or_fail_with("a NoInput callback should ignore the input")
/// }
/// ```
pub type Callback(input, output) {
  /// A function with no argument. The input is not given to it.
  NoInput(run: fn() -> output)
  /// A function that gets the input, for example the context.
  WithInput(run: fn(input) -> output)
}

/// Call a `Callback` with an input.
///
/// ## Parameters
///
/// - `callback`: the test body or hook
/// - `input`: the value that a `WithInput` callback gets. A `NoInput`
///   callback does not get it.
///
/// ## Returns
///
/// What the callback returns.
///
/// ## Example
///
/// ### Call a WithInput callback <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/call.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// pub fn with_input_gets_the_input() -> Result(AssertionResult, String) {
///   types.call(types.WithInput(double), 21)
///   |> should
///   |> be_equal(42)
///   |> or_fail_with("a WithInput callback should get the input")
/// }
/// ```
pub fn call(
  callback callback: Callback(input, output),
  input input: input,
) -> output {
  case callback {
    NoInput(run) -> run()
    WithInput(run) -> run(input)
  }
}

/// Where the tests of a suite get their context.
///
/// ## Variants
///
/// - `FixedContext(value)`: every test starts from `value`, as from the
///   `initial` value of a `Tree`.
/// - `ContextFromSetup(setup, teardown)`: `setup` runs once for the tree,
///   before its first test, and only when at least one test of the tree
///   runs. Its value is the context of every hook and test. `teardown`
///   gets the same value after the last test. Both run in one process that
///   lives while the tests run, so a process that the setup starts and
///   links stays alive. When the setup returns `Error`, crashes or times
///   out, each test is `SetupFailed` and the teardown does not run.
///
/// `unit_context.describe_with_setup` and `steps.new_with_setup` make a
/// `ContextFromSetup`.
pub type SuiteContext(context) {
  FixedContext(value: context)
  ContextFromSetup(
    setup: fn() -> Result(context, String),
    teardown: fn(context) -> Result(Nil, String),
  )
}

/// Construct a tree with a single top-level group.
///
/// This is primarily a low-level helper; most users should start from
/// `dream_test/unit.describe` or `dream_test/unit_context.describe`.
///
/// ## Parameters
///
/// - `name`: name of the top-level group
/// - `initial`: the initial context value stored in the `Tree`
/// - `children`: children under the top-level group
///
/// ## Returns
///
/// A `Tree(context)` with the name, no tags, and the children.
///
/// ## Example
///
/// ### Build a tree with no children <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/tree_function.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/types.{type Tree}
///
/// pub fn empty_math_tree() -> Tree(Int) {
///   types.tree(name: "math", initial: 0, children: [])
/// }
/// ```
pub fn tree(
  name name: String,
  initial initial: context,
  children children: List(Node(context)),
) -> Tree(context) {
  Tree(initial: initial, name: name, tags: [], children: children)
}

/// The complete name of a test: its group names, then its own name.
///
/// `TestResult` and `TestInfo` keep the group names and the test name in
/// two fields, so a full name always has the test name as its last item
/// and is never empty. Use `full_name` when you need the full name as one
/// list, for example to show it, to make an identifier, or to compare two
/// tests. The JSON reporter writes this list as `full_name`.
///
/// ## Parameters
///
/// - `groups`: the names of the groups around the test, from the outermost
///   group in (the `groups` field)
/// - `name`: the test's own name (the `name` field)
///
/// ## Returns
///
/// The group names followed by the test name.
///
/// ## Example
///
/// ### Make the full name of a test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/full_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn groups_then_test_name() -> Result(AssertionResult, String) {
///   types.full_name(["Cart", "totals"], "adds tax")
///   |> should
///   |> be_equal(["Cart", "totals", "adds tax"])
///   |> or_fail_with("expected the group names, then the test name")
/// }
/// ```
pub fn full_name(
  groups groups: List(String),
  name name: String,
) -> List(String) {
  list.append(groups, [name])
}

/// Derive a Status from a list of failures.
///
/// Returns `Passed` if there are no failures, `Failed` otherwise.
///
/// This helper is used when a test body (or hook) accumulates a list of
/// `AssertionFailure`s and needs to compute a summary status.
///
/// ## Parameters
///
/// - `failures`: assertion failures accumulated while running a test
///
/// ## Returns
///
/// - `Passed` when `failures` is empty
/// - `Failed` otherwise
///
/// ## Example
///
/// ### Get Passed for no failures <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/status_from_failures.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn no_failures_means_passed() -> Result(AssertionResult, String) {
///   types.status_from_failures([])
///   |> should
///   |> be_equal(types.Passed)
///   |> or_fail_with("expected Passed for empty failures")
/// }
/// ```
///
pub fn status_from_failures(
  failures failures: List(AssertionFailure),
) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}

/// Whether a status means that the test failed: `Failed`, `SetupFailed` or
/// `TimedOut`.
///
/// `failed`, the failure lists of the BDD reporter and the `failed` count
/// that the runner gives the coverage reporter use this check.
/// The summary line counts each status apart: its `<count> failed` is the
/// status `Failed` only. `failed` also counts teardown failures, stopped
/// setups and crashed results reporters.
///
/// ## Parameters
///
/// - `status`: the status of a test
///
/// ## Returns
///
/// `True` for `Failed`, `SetupFailed` and `TimedOut`, `False` for `Passed`,
/// `Skipped` and `Pending`.
///
/// ## Example
///
/// ### Check that SetupFailed is a failure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/is_failure.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn setup_failed_is_a_failure() -> Result(AssertionResult, String) {
///   types.is_failure(types.SetupFailed)
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("SetupFailed should be a failure")
/// }
/// ```
pub fn is_failure(status status: Status) -> Bool {
  case status {
    Failed -> True
    SetupFailed -> True
    TimedOut -> True
    Passed -> False
    Skipped -> False
    Pending -> False
  }
}

/// A teardown hook. A `TeardownFailed` names the hook that failed.
///
/// Each variant is the hook of the builder function with the same name:
///
/// - `AfterEachTestHook`: `runner.after_each_test`
/// - `AfterEachHook`: `unit.after_each` (and the same hook of the other DSLs)
/// - `AfterAllHook`: `unit.after_all` (and the same hook of the other DSLs)
/// - `AfterEachSuiteHook`: `runner.after_each_suite`
/// - `AfterAllSuitesHook`: `runner.after_all_suites`
/// - `ContextTeardownHook`: the teardown of a tree whose context comes from
///   a setup (`unit_context.describe_with_setup`,
///   `steps.new_with_setup`). It runs after the last test of that tree.
///   Its name is `"context teardown"`.
pub type TeardownHook {
  AfterEachTestHook
  AfterEachHook
  AfterAllHook
  AfterEachSuiteHook
  AfterAllSuitesHook
  ContextTeardownHook
}

/// The name of a teardown hook, as reporters show it.
///
/// ## Parameters
///
/// - `hook`: the teardown hook
///
/// ## Returns
///
/// The name of the builder function of the hook, for example
/// `"after_all"` for `AfterAllHook`.
///
/// ## Example
///
/// ### Get the builder name of a teardown hook <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/teardown_hook_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn after_each_suite_builder_name() -> Result(AssertionResult, String) {
///   types.teardown_hook_name(types.AfterEachSuiteHook)
///   |> should
///   |> be_equal("after_each_suite")
///   |> or_fail_with("expected the builder name")
/// }
/// ```
pub fn teardown_hook_name(hook hook: TeardownHook) -> String {
  case hook {
    AfterEachTestHook -> "after_each_test"
    AfterEachHook -> "after_each"
    AfterAllHook -> "after_all"
    AfterEachSuiteHook -> "after_each_suite"
    AfterAllSuitesHook -> "after_all_suites"
    ContextTeardownHook -> "context teardown"
  }
}

/// The setup hook whose resources a process keeps alive. A `SetupStopped`
/// failure names it.
///
/// Each variant is the hook of the builder function with the same name:
///
/// - `BeforeAllHook`: `unit.before_all` (and the same hook of the other
///   DSLs). It serves the tests of one group.
/// - `BeforeEachSuiteHook`: `runner.before_each_suite`. It serves the tests
///   of one suite.
/// - `BeforeAllSuitesHook`: `runner.before_all_suites`. It serves every
///   test of the run.
/// - `ContextSetupHook`: the setup of a tree whose context comes from a
///   setup (`unit_context.describe_with_setup`, `steps.new_with_setup`).
///   It runs once, before the first test of that tree, and its value is
///   the context of the tests of that tree. Its name is `"context setup"`.
pub type SetupHook {
  BeforeAllHook
  BeforeEachSuiteHook
  BeforeAllSuitesHook
  ContextSetupHook
}

/// The name of a setup hook, as reporters show it.
///
/// ## Parameters
///
/// - `hook`: the setup hook
///
/// ## Returns
///
/// The name of the builder function of the hook, for example
/// `"before_all"` for `BeforeAllHook`.
///
/// ## Example
///
/// ### Get the builder name of a setup hook <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/setup_hook_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn before_all_suites_builder_name() -> Result(AssertionResult, String) {
///   types.setup_hook_name(types.BeforeAllSuitesHook)
///   |> should
///   |> be_equal("before_all_suites")
///   |> or_fail_with("expected the builder name")
/// }
/// ```
pub fn setup_hook_name(hook hook: SetupHook) -> String {
  case hook {
    BeforeAllHook -> "before_all"
    BeforeEachSuiteHook -> "before_each_suite"
    BeforeAllSuitesHook -> "before_all_suites"
    ContextSetupHook -> "context setup"
  }
}

/// A failure at the end of a scope: a teardown hook that returned `Error`
/// or crashed, or a setup that stopped.
///
/// A teardown failure does not change the status of a test. The run keeps
/// it in its own list, and the run fails.
///
/// ## Variants
///
/// - `TeardownFailed(hook, path, message)`: a teardown hook failed.
///   `hook` is the hook. `path` is where it ran: the group names from the
///   top, and for a per-test hook (`AfterEachTestHook`, `AfterEachHook`)
///   the test name last, so the full name of the test. For `AfterAllHook`,
///   the group path. For `ContextTeardownHook` (the teardown of a
///   context setup), the group path of the tree: the groups around it and
///   its name. For `AfterEachSuiteHook`, the suite name. For
///   `AfterAllSuitesHook`, `[]`. `message` is the error message of the
///   hook, or the crash text.
/// - `SetupStopped(setup, path, reason, not_run)`: a setup stopped.
///   The process that keeps its setup alive exited while or after its
///   setup hooks ran, for example because a `before_all` hook killed it,
///   or a process that the hook linked to it crashed. `setup` is the
///   setup hook. `path` is the group path for `BeforeAllHook`, the group
///   path of the tree for `ContextSetupHook` (a context setup), the suite
///   name for `BeforeEachSuiteHook` and `[]` for `BeforeAllSuitesHook`.
///   `reason` is the exit reason of the process. The tests of the scope
///   that had not started are not run: each one is `SetupFailed` with the
///   failure `not run: the setup from <setup hook> in "<groups>" stopped
///   (<reason>)`, without `in "<groups>"` for `BeforeAllSuitesHook`, or
///   `not run: the context setup of "<tree>" stopped (<reason>)` for
///   `ContextSetupHook`, where `<tree>` is the group path joined with
///   ` > `. `not_run` is the full name of each of these tests (see
///   `full_name`), in the order of the run. The runner records each test
///   when it skips it. When a test is in the scope of more than one
///   stopped setup, the outermost one records it. The teardown hooks of
///   the scope run in a new process.
///
/// ## Example
///
/// ### Make a teardown failure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/hook_failure.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/types
///
/// pub fn drop_schema_failure() -> types.HookFailure {
///   types.TeardownFailed(
///     hook: types.AfterAllHook,
///     path: ["Database"],
///     message: "could not drop the test schema",
///   )
/// }
/// ```
pub type HookFailure {
  TeardownFailed(hook: TeardownHook, path: List(String), message: String)
  SetupStopped(
    setup: SetupHook,
    path: List(String),
    reason: String,
    not_run: List(List(String)),
  )
}

/// A results reporter whose render function crashed.
///
/// `runner.run` records one for each `reporter_types.Custom` reporter whose
/// render function crashed. Read them with `report_reporter_crashes`. The
/// runner sets the fields like this:
///
/// - `position`: the place of the reporter in the list that
///   `runner.results_reporters` got, counted from 1. The first reporter is
///   at position 1, and every reporter in the list counts, the BDD and
///   JSON reporters included.
/// - `reason`: the crash, as `class:reason`, for example
///   `error:badarith`. This is the full text, which can be longer than one
///   line. The error output shows it on one line: the lines of the reason,
///   each without the spaces at its start, joined with one space. When
///   that line is longer than 200 characters, the error output shows the
///   first 200 characters and then ` ... (cut at 200 characters, and
///   types.report_reporter_crashes has the full reason)`.
///
/// ## Example
///
/// ### Make a reporter crash <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/reporter_crash.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/types
///
/// pub fn second_reporter_crash() -> types.ReporterCrash {
///   types.ReporterCrash(position: 2, reason: "error:badarith")
/// }
/// ```
pub type ReporterCrash {
  ReporterCrash(position: Int, reason: String)
}

/// The result of a run: the result of each test, the teardown hooks that
/// failed, the results reporters that crashed, and whether a run with no
/// test is allowed.
///
/// `runner.run` and `parallel.run_tree_parallel` give a `RunReport`, and the
/// reporters take one. Use `run_report` to make one, `report_tests`,
/// `report_hook_failures` and `report_reporter_crashes` to read it, and
/// `failed` and `failed_with_no_tests` to check it.
pub opaque type RunReport {
  RunReport(
    tests: List(TestResult),
    hook_failures: List(HookFailure),
    reporter_crashes: List(ReporterCrash),
    no_tests_allowed: Bool,
  )
}

/// Make a `RunReport`.
///
/// The runner makes the report of a run. Make one yourself to test a
/// reporter, or in a custom runner.
///
/// ## Parameters
///
/// - `tests`: the result of each test, in the order of the run
/// - `hook_failures`: the teardown hooks that failed and the setups
///   that stopped, in the order that they happened
/// - `reporter_crashes`: the results reporters that crashed, in list order.
///   Give `[]` when no reporter crashed, or when no reporter ran yet.
///
/// ## Returns
///
/// A `RunReport` with these tests, hook failures and crashed results
/// reporters. A report with no test result has failed, until you give it
/// to `allow_no_tests`.
///
/// ## Example
///
/// ### Make an empty run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/run_report.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn empty_run_fails() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.failed
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("a run with no test should fail")
/// }
/// ```
pub fn run_report(
  tests tests: List(TestResult),
  hook_failures hook_failures: List(HookFailure),
  reporter_crashes reporter_crashes: List(ReporterCrash),
) -> RunReport {
  RunReport(
    tests: tests,
    hook_failures: hook_failures,
    reporter_crashes: reporter_crashes,
    no_tests_allowed: False,
  )
}

/// Allow a run with no test result: `failed` and `failed_with_no_tests`
/// then do not count it as a failure, and the reporters show no
/// `No tests ran` line.
///
/// `runner.allow_no_tests` calls it on the report of the run. Call it
/// yourself in a custom runner.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// The same report, with a run of no test allowed.
///
/// ## Example
///
/// ### Allow an empty run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/allow_no_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn allowed_empty_run_passes() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.allow_no_tests
///   |> types.failed
///   |> should
///   |> be_equal(False)
///   |> or_fail_with("an allowed empty run should not fail")
/// }
/// ```
pub fn allow_no_tests(report report: RunReport) -> RunReport {
  RunReport(..report, no_tests_allowed: True)
}

/// The result of each test of a run, in the order of the run.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// The test results. Hook failures are not test results.
///
/// ## Example
///
/// ### Read the tests of a run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/report_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn empty_run_has_no_tests() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.report_tests
///   |> should
///   |> be_equal([])
///   |> or_fail_with("an empty run should have no tests")
/// }
/// ```
pub fn report_tests(report report: RunReport) -> List(TestResult) {
  report.tests
}

/// The hook failures of a run: the teardown hooks that failed and the
/// setups that stopped, in the order that they happened.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// The hook failures, or `[]` when no teardown hook failed and no setup
/// stopped.
///
/// ## Example
///
/// ### Read the hook failures of a run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/report_hook_failures.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn empty_run_has_no_hook_failures() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.report_hook_failures
///   |> should
///   |> be_equal([])
///   |> or_fail_with("an empty run should have no hook failures")
/// }
/// ```
pub fn report_hook_failures(report report: RunReport) -> List(HookFailure) {
  report.hook_failures
}

/// The results reporters whose render function crashed in a run, in list
/// order.
///
/// Use it when your code picks its own exit status from the report, or
/// writes the crash somewhere else.
///
/// Only the report that `runner.run` returns has the crashes. The results
/// reporters get the report before any reporter ran, so a reporter later
/// in the list does not see the crash of a reporter before it.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// The crashes, or `[]` when no results reporter crashed.
///
/// ## Example
///
/// ### Read the crashed reporters of a run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/report_reporter_crashes.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn empty_run_has_no_crashed_reporters() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.report_reporter_crashes
///   |> should
///   |> be_equal([])
///   |> or_fail_with("an empty run should have no crashed reporters")
/// }
/// ```
pub fn report_reporter_crashes(
  report report: RunReport,
) -> List(ReporterCrash) {
  report.reporter_crashes
}

/// Whether a run failed: a test has a failure status (see `is_failure`), a
/// teardown hook failed, a results reporter crashed, or the run ran no
/// test (see `failed_with_no_tests`).
///
/// `runner.exit_on_failure` ends the program with status 1 when this is
/// `True`.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// `True` when a test is `Failed`, `SetupFailed` or `TimedOut`, when the
/// report has a teardown failure, when it has a crashed results
/// reporter, or when `failed_with_no_tests` is `True`.
///
/// ## Example
///
/// ### Fail a run with a teardown failure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/failed.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn teardown_failure_fails_the_run() -> Result(AssertionResult, String) {
///   types.run_report(
///     tests: [],
///     hook_failures: [
///       types.TeardownFailed(
///         hook: types.AfterAllSuitesHook,
///         path: [],
///         message: "could not stop the pool",
///       ),
///     ],
///     reporter_crashes: [],
///   )
///   |> types.failed
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("a teardown failure should fail the run")
/// }
/// ```
pub fn failed(report report: RunReport) -> Bool {
  !list.is_empty(report.hook_failures)
  || !list.is_empty(report.reporter_crashes)
  || list.any(report.tests, has_failure_status)
  || failed_with_no_tests(report)
}

/// Whether a run failed because it ran no test: the report has no test
/// result, and `allow_no_tests` was not called on it.
///
/// A test that is `Skipped` or `Pending` is a test result: the run
/// selected it. So a run where every test is skipped or pending did not
/// fail this way. A filter that keeps no test, and `runner.new([])`, give
/// a run with no test result.
///
/// The BDD and Gherkin reporters show a `No tests ran` line after the
/// summary line when this is `True` (see `summary.format`).
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// `True` when the report has no test result and does not allow that.
///
/// ## Example
///
/// ### Fail a run that ran no test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/types/failed_with_no_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn empty_run_failed_with_no_tests() -> Result(AssertionResult, String) {
///   types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
///   |> types.failed_with_no_tests
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("a run with no test should fail with no tests")
/// }
/// ```
pub fn failed_with_no_tests(report report: RunReport) -> Bool {
  list.is_empty(report.tests) && !report.no_tests_allowed
}

fn has_failure_status(result: TestResult) -> Bool {
  is_failure(result.status)
}
