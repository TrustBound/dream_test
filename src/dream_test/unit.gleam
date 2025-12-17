//// Suite-first unit test DSL for dream_test.
////
//// This module constructs `types.TestSuite(ctx)` values directly.
////
//// ## Mental model
////
//// A **suite** is a named container of tests and hooks.
//// A **group** is just a nested suite used for organization and hook scoping.
////
//// Each suite tree has exactly one context type `ctx`, created once by
//// `before_all` (or defaulted to `Nil` when you use plain `describe`).
////
//// - Root suites are built with `describe(name, children)`.
//// - Nested groups are built with `group(name, children)`.
//// - One context type per suite tree:
////   - `before_all` runs once (root-only) and creates the initial context.
////   - `before_each` runs before each test and can transform the context for that test.
////   - `after_each` runs after each test (always) for cleanup.
////   - `after_all` runs once at the end (even on failure).
////
//// All hooks/tests return `Result` to allow short-circuiting via `Error(String)`.
////
//// ## Errors
////
//// Returning `Error("message")` from a hook or test body marks the test as
//// failed (or setup-failed) with that message. Use this to abort quickly when
//// preconditions are not met.
////
//// ## Example
////
//// ```gleam
//// import dream_test/unit.{describe, it}
//// import dream_test/types.{AssertionOk}
////
//// pub fn tests() {
////   describe("Math", [
////     it("adds", fn(_) { Ok(AssertionOk) }),
////   ])
//// }
//// ```

import dream_test/types.{
  type AssertionResult, type SuiteTestCase, type TestSuite, type TestSuiteItem,
  AssertionSkipped, SuiteGroup, SuiteTest, SuiteTestCase, TestSuite, Unit,
}
import gleam/list
import gleam/option.{type Option, None, Some}

/// Hook configuration for `describe_with_hooks`.
///
/// This is a small builder record so you can add hooks without a long argument
/// list.
///
/// You only need `SuiteHooks` when you want a non-`Nil` context type (i.e. you
/// want `before_all` to produce something other than `Nil`).
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit
///
/// let hooks =
///   unit.hooks(fn() { Ok(0) })
///   |> unit.hooks_before_each(fn(n) { Ok(n + 1) })
/// ```
pub type SuiteHooks(ctx) {
  SuiteHooks(
    before_all: fn() -> Result(ctx, String),
    after_all: List(fn(ctx) -> Result(Nil, String)),
    before_each: List(fn(ctx) -> Result(ctx, String)),
    after_each: List(fn(ctx) -> Result(Nil, String)),
  )
}

/// Start building hooks by defining the required `before_all`.
///
/// ## Example
///
/// ```gleam
/// let hooks = hooks(fn() { Ok("ctx") })
/// ```
///
/// ## Parameters
///
/// - `before_all`: a function that runs once and produces the initial context
///
/// ## Returns
///
/// A `SuiteHooks(ctx)` value you can extend with `hooks_before_each`,
/// `hooks_after_each`, and `hooks_after_all`.
pub fn hooks(before_all: fn() -> Result(ctx, String)) -> SuiteHooks(ctx) {
  SuiteHooks(
    before_all: before_all,
    after_all: [],
    before_each: [],
    after_each: [],
  )
}

/// Add an `after_all` hook to a `SuiteHooks`.
///
/// Hooks are appended in the order you add them.
///
/// ## Example
///
/// ```gleam
/// let hooks =
///   hooks(fn() { Ok(Nil) })
///   |> hooks_after_all(fn(_ctx) { Ok(Nil) })
/// ```
///
/// ## Parameters
///
/// - `hooks`: existing hook configuration
/// - `teardown`: runs once after the suite finishes
///
/// ## Returns
///
/// Updated `SuiteHooks(ctx)`.
pub fn hooks_after_all(
  hooks: SuiteHooks(ctx),
  teardown: fn(ctx) -> Result(Nil, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, after_all: list.append(hooks.after_all, [teardown]))
}

/// Add a `before_each` hook to a `SuiteHooks`.
///
/// `before_each` hooks can transform the context for the test.
///
/// ## Example
///
/// ```gleam
/// let hooks =
///   hooks(fn() { Ok(0) })
///   |> hooks_before_each(fn(n) { Ok(n + 1) })
/// ```
///
/// ## Parameters
///
/// - `hooks`: existing hook configuration
/// - `setup`: runs before each test and can transform the context
///
/// ## Returns
///
/// Updated `SuiteHooks(ctx)`.
pub fn hooks_before_each(
  hooks: SuiteHooks(ctx),
  setup: fn(ctx) -> Result(ctx, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, before_each: list.append(hooks.before_each, [setup]))
}

/// Add an `after_each` hook to a `SuiteHooks`.
///
/// ## Example
///
/// ```gleam
/// let hooks =
///   hooks(fn() { Ok(Nil) })
///   |> hooks_after_each(fn(_ctx) { Ok(Nil) })
/// ```
///
/// ## Parameters
///
/// - `hooks`: existing hook configuration
/// - `teardown`: runs after each test
///
/// ## Returns
///
/// Updated `SuiteHooks(ctx)`.
pub fn hooks_after_each(
  hooks: SuiteHooks(ctx),
  teardown: fn(ctx) -> Result(Nil, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, after_each: list.append(hooks.after_each, [teardown]))
}

/// Items that can appear inside a `describe`/`group` block.
///
/// We keep these as a single type so children lists remain homogeneous.
///
/// Most users should construct `SuiteItem`s using the helper functions in this
/// module (`it`, `group`, `before_each`, etc.) rather than using the
/// constructors directly.
pub type SuiteItem(ctx) {
  SuiteTestItem(SuiteTestCase(ctx))
  SuiteGroupItem(TestSuite(ctx))
  BeforeAllItem(fn() -> Result(ctx, String))
  BeforeEachItem(fn(ctx) -> Result(ctx, String))
  AfterEachItem(fn(ctx) -> Result(Nil, String))
  AfterAllItem(fn(ctx) -> Result(Nil, String))
}

/// Define a single test case.
///
/// The function receives the current suite context.
///
/// ## Parameters
///
/// - `name`: test label shown in reports
/// - `run`: receives the context for this test; return `Ok(AssertionOk)` to pass
///
/// ## Returns
///
/// A `SuiteItem(ctx)` suitable for inclusion in a `describe`/`group` children list.
///
/// ## Example
///
/// ```gleam
/// it("passes", fn(_ctx) { Ok(AssertionOk) })
/// ```
pub fn it(
  name: String,
  run: fn(ctx) -> Result(AssertionResult, String),
) -> SuiteItem(ctx) {
  SuiteTestItem(SuiteTestCase(
    name: name,
    tags: [],
    kind: Unit,
    run: run,
    timeout_ms: None,
  ))
}

/// Skip a test case.
///
/// The provided function is ignored.
///
/// ## Parameters
///
/// - `name`: test label shown in reports
/// - `_run`: ignored (kept to make it easy to “toggle” between `it` and `skip`)
///
/// ## Returns
///
/// A `SuiteItem(ctx)` that will always produce `AssertionSkipped`.
///
/// ## Example
///
/// ```gleam
/// skip("TODO: implement", fn(_ctx) { Ok(AssertionOk) })
/// ```
pub fn skip(
  name: String,
  _run: fn(ctx) -> Result(AssertionResult, String),
) -> SuiteItem(ctx) {
  SuiteTestItem(SuiteTestCase(
    name: name,
    tags: [],
    kind: Unit,
    run: skip_run,
    timeout_ms: None,
  ))
}

fn skip_run(_ctx: ctx) -> Result(AssertionResult, String) {
  Ok(AssertionSkipped)
}

/// Add tags to a test item.
///
/// Tags are used by the runner for filtering.
///
/// If you call this on a non-test item (e.g. a hook or group), it is a no-op.
///
/// ## Parameters
///
/// - `item`: usually the result of `it(...)` or `skip(...)`
/// - `tags`: replacement tag list (not appended)
///
/// ## Returns
///
/// The updated item.
///
/// ## Example
///
/// ```gleam
/// it("db test", fn(_) { Ok(AssertionOk) })
/// |> with_tags(["integration"])
/// ```
pub fn with_tags(item: SuiteItem(ctx), tags: List(String)) -> SuiteItem(ctx) {
  case item {
    SuiteTestItem(test_case) ->
      SuiteTestItem(SuiteTestCase(..test_case, tags: tags))
    other -> other
  }
}

/// Root suite constructor.
///
/// Root suites always have a context. If you do not provide a `before_all`,
/// the context is implicitly `Nil`.
///
/// If you need a typed context, use `describe_with_hooks`.
///
/// ## Parameters
///
/// - `name`: suite label shown in reports
/// - `children`: tests, groups, and hooks created via this module
///
/// ## Returns
///
/// A `TestSuite(Nil)` you can pass to `runner.new([suite])`.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   it("runs", fn(_) { Ok(AssertionOk) }),
/// ])
/// ```
pub fn describe(name: String, children: List(SuiteItem(Nil))) -> TestSuite(Nil) {
  let suite = build_suite(name, children, True)
  let before_all = case suite.before_all {
    Some(setup) -> setup
    None -> default_before_all_nil
  }

  TestSuite(
    ..suite,
    before_all: Some(before_all),
    has_user_before_all: option.is_some(suite.before_all),
  )
}

fn default_before_all_nil() -> Result(Nil, String) {
  Ok(Nil)
}

/// Root suite constructor with typed hooks/context.
///
/// `describe_with_hooks` is the escape hatch when you want a strongly typed
/// context (anything other than `Nil`) shared by hooks and tests.
///
/// ## Parameters
///
/// - `name`: suite label shown in reports
/// - `hooks`: hook configuration (must include a `before_all` that produces `ctx`)
/// - `children`: suite items (`it`, `group`, `before_each`, etc.) using the same `ctx`
///
/// ## Returns
///
/// A `TestSuite(ctx)` you can pass to `runner.new([suite])`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/assertions/should.{equal, or_fail_with, should}
/// import dream_test/unit.{describe_with_hooks, hooks, it}
///
/// let hooks = hooks(fn() { Ok(41) })
///
/// describe_with_hooks("Root", hooks, [
///   it("sees ctx", fn(n) {
///     n + 1
///     |> should()
///     |> equal(42)
///     |> or_fail_with("ctx should be 41")
///   }),
/// ])
/// ```
pub fn describe_with_hooks(
  name: String,
  hooks: SuiteHooks(ctx),
  children: List(SuiteItem(ctx)),
) -> TestSuite(ctx) {
  let suite = build_suite(name, children, False)

  TestSuite(
    ..suite,
    before_all: Some(hooks.before_all),
    has_user_before_all: True,
    after_all: list.append(hooks.after_all, suite.after_all),
    before_each: list.append(hooks.before_each, suite.before_each),
    after_each: list.append(hooks.after_each, suite.after_each),
  )
}

/// Nested group constructor.
///
/// Nested groups are suites, but **cannot** declare `before_all` (enforced).
///
/// Groups exist so you can:
///
/// - organize tests under a shared name prefix
/// - scope `before_each`/`after_each` hooks to just a subsection
///
/// ## Parameters
///
/// - `name`: group label shown in reports
/// - `children`: suite items using the same `ctx`
///
/// ## Returns
///
/// A `SuiteItem(ctx)` suitable for inclusion in a parent suite.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   group("nested", [
///     it("runs", fn(_) { Ok(AssertionOk) }),
///   ]),
/// ])
/// ```
pub fn group(name: String, children: List(SuiteItem(ctx))) -> SuiteItem(ctx) {
  SuiteGroupItem(build_suite(name, children, False))
}

/// Declare a `before_all` hook (root suites only).
///
/// This is only allowed directly under `describe` / `describe_with_hooks`.
/// Declaring it under a `group` causes a runtime panic.
///
/// Returning `Error("message")` from `before_all` marks every test in the suite
/// as `SetupFailed`.
///
/// ## Parameters
///
/// - `setup`: runs once and produces the initial `ctx`
///
/// ## Returns
///
/// A `SuiteItem(ctx)` for use in a root suite’s children list.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   before_all(fn() { Ok(Nil) }),
///   it("runs", fn(_) { Ok(AssertionOk) }),
/// ])
/// ```
pub fn before_all(setup: fn() -> Result(ctx, String)) -> SuiteItem(ctx) {
  BeforeAllItem(setup)
}

/// Declare a `before_each` hook.
///
/// Hooks run outer-to-inner and can transform the context for the test.
///
/// ## Parameters
///
/// - `setup`: runs before each test; return `Ok(updated_ctx)` to continue
///
/// ## Returns
///
/// A `SuiteItem(ctx)` for use in any suite/group children list.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   before_each(fn(ctx) { Ok(ctx) }),
///   it("runs", fn(_) { Ok(AssertionOk) }),
/// ])
/// ```
pub fn before_each(setup: fn(ctx) -> Result(ctx, String)) -> SuiteItem(ctx) {
  BeforeEachItem(setup)
}

/// Declare an `after_each` hook.
///
/// Hooks run inner-to-outer and always run for cleanup.
///
/// If an `after_each` hook returns `Error("message")`, the test is marked failed
/// (even if the test body passed).
///
/// ## Parameters
///
/// - `teardown`: runs after each test
///
/// ## Returns
///
/// A `SuiteItem(ctx)` for use in any suite/group children list.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   after_each(fn(_ctx) { Ok(Nil) }),
///   it("runs", fn(_) { Ok(AssertionOk) }),
/// ])
/// ```
pub fn after_each(teardown: fn(ctx) -> Result(Nil, String)) -> SuiteItem(ctx) {
  AfterEachItem(teardown)
}

/// Declare an `after_all` hook.
///
/// If any `after_all` hook returns `Error`, the run stops and remaining suites
/// are marked `SetupFailed` to avoid potential test pollution.
///
/// ## Parameters
///
/// - `teardown`: runs once after all tests in this root suite finish
///
/// ## Returns
///
/// A `SuiteItem(ctx)` for use in a root suite’s children list.
///
/// ## Example
///
/// ```gleam
/// describe("Root", [
///   after_all(fn(_ctx) { Ok(Nil) }),
///   it("runs", fn(_) { Ok(AssertionOk) }),
/// ])
/// ```
pub fn after_all(teardown: fn(ctx) -> Result(Nil, String)) -> SuiteItem(ctx) {
  AfterAllItem(teardown)
}

fn build_suite(
  name: String,
  children: List(SuiteItem(ctx)),
  allow_before_all: Bool,
) -> TestSuite(ctx) {
  let before_all = select_before_all(children, allow_before_all)
  let after_all_hooks = collect_after_all(children, [])
  let before_each_hooks = collect_before_each(children, [])
  let after_each_hooks = collect_after_each(children, [])
  let items = collect_items(children, [])

  TestSuite(
    name: name,
    before_all: before_all,
    has_user_before_all: option.is_some(before_all),
    after_all: after_all_hooks,
    before_each: before_each_hooks,
    after_each: after_each_hooks,
    items: items,
  )
}

fn select_before_all(
  children: List(SuiteItem(ctx)),
  allow_before_all: Bool,
) -> Option(fn() -> Result(ctx, String)) {
  case allow_before_all {
    True -> find_before_all(children)
    False -> {
      case contains_before_all(children) {
        True -> panic_no_nested_before_all()
        False -> None
      }
    }
  }
}

fn find_before_all(
  children: List(SuiteItem(ctx)),
) -> Option(fn() -> Result(ctx, String)) {
  case children {
    [] -> None
    [child, ..rest] ->
      case child {
        BeforeAllItem(setup) -> Some(setup)
        _ -> find_before_all(rest)
      }
  }
}

fn contains_before_all(children: List(SuiteItem(ctx))) -> Bool {
  case children {
    [] -> False
    [child, ..rest] ->
      case child {
        BeforeAllItem(_) -> True
        _ -> contains_before_all(rest)
      }
  }
}

fn panic_no_nested_before_all() -> Option(fn() -> Result(ctx, String)) {
  panic as "before_all is only allowed at the root describe; nested before_all is not allowed"
}

fn collect_after_all(
  children: List(SuiteItem(ctx)),
  accumulated: List(fn(ctx) -> Result(Nil, String)),
) -> List(fn(ctx) -> Result(Nil, String)) {
  case children {
    [] -> list.reverse(accumulated)
    [child, ..rest] ->
      case child {
        AfterAllItem(teardown) ->
          collect_after_all(rest, [teardown, ..accumulated])
        _ -> collect_after_all(rest, accumulated)
      }
  }
}

fn collect_before_each(
  children: List(SuiteItem(ctx)),
  accumulated: List(fn(ctx) -> Result(ctx, String)),
) -> List(fn(ctx) -> Result(ctx, String)) {
  case children {
    [] -> list.reverse(accumulated)
    [child, ..rest] ->
      case child {
        BeforeEachItem(setup) ->
          collect_before_each(rest, [setup, ..accumulated])
        _ -> collect_before_each(rest, accumulated)
      }
  }
}

fn collect_after_each(
  children: List(SuiteItem(ctx)),
  accumulated: List(fn(ctx) -> Result(Nil, String)),
) -> List(fn(ctx) -> Result(Nil, String)) {
  case children {
    [] -> list.reverse(accumulated)
    [child, ..rest] ->
      case child {
        AfterEachItem(teardown) ->
          collect_after_each(rest, [teardown, ..accumulated])
        _ -> collect_after_each(rest, accumulated)
      }
  }
}

fn collect_items(
  children: List(SuiteItem(ctx)),
  accumulated: List(TestSuiteItem(ctx)),
) -> List(TestSuiteItem(ctx)) {
  case children {
    [] -> list.reverse(accumulated)
    [child, ..rest] ->
      case child {
        SuiteTestItem(test_case) ->
          collect_items(rest, [SuiteTest(test_case), ..accumulated])
        SuiteGroupItem(suite) ->
          collect_items(rest, [SuiteGroup(suite), ..accumulated])
        _ -> collect_items(rest, accumulated)
      }
  }
}
