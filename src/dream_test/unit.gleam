//// Suite-first unit test DSL for dream_test.
////
//// This module constructs `types.TestSuite(ctx)` values directly.
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

import dream_test/types.{
  type AssertionResult, type SuiteTestCase, type TestSuite, type TestSuiteItem,
  AssertionSkipped, SuiteGroup, SuiteTest, SuiteTestCase, TestSuite, Unit,
}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type SuiteHooks(ctx) {
  SuiteHooks(
    before_all: fn() -> Result(ctx, String),
    after_all: List(fn(ctx) -> Result(Nil, String)),
    before_each: List(fn(ctx) -> Result(ctx, String)),
    after_each: List(fn(ctx) -> Result(Nil, String)),
  )
}

pub fn hooks(before_all: fn() -> Result(ctx, String)) -> SuiteHooks(ctx) {
  SuiteHooks(
    before_all: before_all,
    after_all: [],
    before_each: [],
    after_each: [],
  )
}

pub fn hooks_after_all(
  hooks: SuiteHooks(ctx),
  teardown: fn(ctx) -> Result(Nil, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, after_all: list.append(hooks.after_all, [teardown]))
}

pub fn hooks_before_each(
  hooks: SuiteHooks(ctx),
  setup: fn(ctx) -> Result(ctx, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, before_each: list.append(hooks.before_each, [setup]))
}

pub fn hooks_after_each(
  hooks: SuiteHooks(ctx),
  teardown: fn(ctx) -> Result(Nil, String),
) -> SuiteHooks(ctx) {
  SuiteHooks(..hooks, after_each: list.append(hooks.after_each, [teardown]))
}

/// Items that can appear inside a `describe`/`group` block.
///
/// We keep these as a single type so children lists remain homogeneous.
pub type SuiteItem(ctx) {
  SuiteTestItem(SuiteTestCase(ctx))
  SuiteGroupItem(TestSuite(ctx))
  BeforeAllItem(fn() -> Result(ctx, String))
  BeforeEachItem(fn(ctx) -> Result(ctx, String))
  AfterEachItem(fn(ctx) -> Result(Nil, String))
  AfterAllItem(fn(ctx) -> Result(Nil, String))
}

/// Define a single test case.
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
pub fn with_tags(item: SuiteItem(ctx), tags: List(String)) -> SuiteItem(ctx) {
  case item {
    SuiteTestItem(test_case) ->
      SuiteTestItem(SuiteTestCase(..test_case, tags: tags))
    other -> other
  }
}

/// Root suite constructor.
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
pub fn group(name: String, children: List(SuiteItem(ctx))) -> SuiteItem(ctx) {
  SuiteGroupItem(build_suite(name, children, False))
}

pub fn before_all(setup: fn() -> Result(ctx, String)) -> SuiteItem(ctx) {
  BeforeAllItem(setup)
}

pub fn before_each(setup: fn(ctx) -> Result(ctx, String)) -> SuiteItem(ctx) {
  BeforeEachItem(setup)
}

pub fn after_each(teardown: fn(ctx) -> Result(Nil, String)) -> SuiteItem(ctx) {
  AfterEachItem(teardown)
}

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
