//// A test suite, ready to run.
////
//// Every suite has the same type, `TestSuite`, whatever context its tests
//// get. A suite keeps its typed tree and its context inside it, so one run
//// can hold a `unit` suite, a `unit_context` suite and a Gherkin feature:
////
//// ```gleam
//// runner.new([plain_suite(), number_suite(), word_feature()])
//// |> runner.run()
//// ```
////
//// Most code does not use this module directly: `unit.describe`,
//// `unit_context.describe` and the Gherkin functions give a `TestSuite`,
//// and the runner runs it. Use this module to make a suite from a tree that
//// you build yourself (`from_root`), to put suites in one group (`group`),
//// or to read what a suite holds (`name`, `tests`).

import dream_test/parallel.{
  type OuterSetup, type ParallelConfig, type RunRootParallelWithReporterResult,
  RunRootParallelWithReporterResult, RunSuiteConfig,
}
import dream_test/reporters/progress.{type ProgressReporter}
import dream_test/types.{
  type Node, type Root, type TestInfo, AfterAll, AfterEach, BeforeAll,
  BeforeEach, Group, Test, TestInfo,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

/// A suite that the runner can run.
///
/// Make one with `unit.describe`, `unit_context.describe`, the Gherkin
/// functions or `from_root`. The context of the tests is inside the suite,
/// so it does not show in the type: suites with different contexts go in
/// one list.
pub opaque type TestSuite {
  TestSuite(name: String, parts: List(Part))
}

/// One typed tree of a suite. A suite from `group` or `join` has a part for
/// each tree in it, and each part keeps its own context.
type Part {
  Part(
    place: Place,
    tests: List(TestInfo),
    tests_at: fn(Place) -> List(TestInfo),
    run: fn(Place, RunInput) -> RunRootParallelWithReporterResult,
  )
}

/// Where a part runs: inside the groups `groups`, outermost first, and with
/// `source` as the source of each test when it is `Some`.
type Place {
  Place(groups: List(String), source: Option(String))
}

/// What `run` needs from the runner.
///
/// - `config`: the concurrency and the default timeout.
/// - `keep`: `Some(predicate)` runs only the tests that the predicate keeps
///   (see `runner.filter_tests`). A tree with no kept test does not run.
///   `None` runs every test.
/// - `progress_reporter`, `write`, `total`, `completed`: the progress
///   output, as in `parallel.RunRootParallelWithReporterConfig`.
/// - `before_each_test`, `after_each_test`: the runner hooks around each
///   test (see `runner.before_each_test`). They get the `TestInfo` of the
///   test, not its context.
/// - `outer_setups`: the set-ups around the suite (see
///   `parallel.OuterSetup`).
pub type RunInput {
  RunInput(
    config: ParallelConfig,
    keep: Option(fn(TestInfo) -> Bool),
    progress_reporter: Option(ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
    before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    outer_setups: List(OuterSetup),
  )
}

/// Make a suite from a typed tree that you build yourself.
///
/// The `seed` of the root is the context of the tests. `unit.describe`
/// and `unit_context.describe` call this for you.
///
/// ## Parameters
///
/// - `root`: the tree, with its name, tags, children and context
///
/// ## Returns
///
/// A `TestSuite` with the tests of the tree.
///
/// ## Example
///
/// ```gleam
/// suite.from_root(types.root("numbers", 41, [unit_context.it("is 41", is_41)]))
/// ```
pub fn from_root(root root: Root(context)) -> TestSuite {
  TestSuite(name: root.name, parts: [root_part(root)])
}

/// The name of the suite: the name of its top-level group.
///
/// ## Example
///
/// ```gleam
/// suite.name(unit.describe("Cart", []))
/// // -> "Cart"
/// ```
pub fn name(suite suite: TestSuite) -> String {
  suite.name
}

/// The `TestInfo` of each test of the suite, in the order of the run.
///
/// ## Example
///
/// ```gleam
/// suite.tests(unit.describe("Cart", [unit.it("is empty", is_empty)]))
/// |> list.map(fn(info) { info.name })
/// // -> ["is empty"]
/// ```
pub fn tests(suite suite: TestSuite) -> List(TestInfo) {
  list.flat_map(suite.parts, part_tests)
}

/// Put suites in one group with the name `name`.
///
/// Each suite becomes a group inside the new suite, and keeps its own
/// context. The suites run one after the other. The group name is the
/// first group of each test, also in the progress output.
///
/// ## Example
///
/// ```gleam
/// suite.group(name: "all", suites: [plain_suite(), number_suite()])
/// ```
pub fn group(name name: String, suites suites: List(TestSuite)) -> TestSuite {
  TestSuite(
    name: name,
    parts: list.map(list.flat_map(suites, suite_parts), put_in_group(_, name)),
  )
}

/// Put suites one after the other in one suite with the name `name`.
///
/// Unlike `group`, `join` adds no group: each test keeps its own groups,
/// and each suite keeps its own context. The runner sees one suite, so
/// `runner.before_each_suite` runs once for all of them.
///
/// ## Example
///
/// ```gleam
/// suite.join(name: "checkout", suites: [cart_suite(), payment_suite()])
/// ```
pub fn join(name name: String, suites suites: List(TestSuite)) -> TestSuite {
  TestSuite(name: name, parts: list.flat_map(suites, suite_parts))
}

/// Give each test of the suite the source `source`, for example the name
/// of the module that made the suite. Module discovery does this.
///
/// ## Example
///
/// ```gleam
/// suite.with_source(suite: tests(), source: "cart_test")
/// ```
pub fn with_source(suite suite: TestSuite, source source: String) -> TestSuite {
  TestSuite(..suite, parts: list.map(suite.parts, set_source(_, source)))
}

/// Run the tests of the suite. The runner calls this for each suite.
///
/// Each tree of the suite runs with its own context, one tree after the
/// other. A tree with no test to run does not run.
///
/// ## Parameters
///
/// - `suite`: the suite to run
/// - `input`: what the run needs (see `RunInput`)
///
/// ## Returns
///
/// The results and the tear-down failures of the suite, in the order that
/// they ran, the new count of completed tests, and the outer set-ups as
/// the executor saw them last.
pub fn run(
  suite suite: TestSuite,
  input input: RunInput,
) -> RunRootParallelWithReporterResult {
  list.fold(suite.parts, nothing_ran(input), fn(ran, part) {
    run_next_part(input, ran, part)
  })
}

// ============================================================================
// Parts
// ============================================================================

fn suite_parts(suite: TestSuite) -> List(Part) {
  suite.parts
}

fn part_tests(part: Part) -> List(TestInfo) {
  part.tests
}

fn put_in_group(part: Part, name: String) -> Part {
  move_part(part, Place(..part.place, groups: [name, ..part.place.groups]))
}

fn set_source(part: Part, source: String) -> Part {
  move_part(part, Place(..part.place, source: Some(source)))
}

fn move_part(part: Part, place: Place) -> Part {
  Part(..part, place: place, tests: part.tests_at(place))
}

fn run_next_part(
  input: RunInput,
  ran: RunRootParallelWithReporterResult,
  part: Part,
) -> RunRootParallelWithReporterResult {
  let next =
    part.run(
      part.place,
      RunInput(
        ..input,
        progress_reporter: ran.progress_reporter,
        completed: ran.completed,
        outer_setups: ran.outer_setups,
      ),
    )
  RunRootParallelWithReporterResult(
    results: list.append(ran.results, next.results),
    teardown_failures: list.append(
      ran.teardown_failures,
      next.teardown_failures,
    ),
    completed: next.completed,
    progress_reporter: next.progress_reporter,
    outer_setups: next.outer_setups,
  )
}

fn nothing_ran(input: RunInput) -> RunRootParallelWithReporterResult {
  RunRootParallelWithReporterResult(
    results: [],
    teardown_failures: [],
    completed: input.completed,
    progress_reporter: input.progress_reporter,
    outer_setups: input.outer_setups,
  )
}

// ============================================================================
// Typed trees
// ============================================================================

fn root_part(root: Root(context)) -> Part {
  let place = Place(groups: [], source: None)
  Part(
    place: place,
    tests: root_tests(root, place),
    tests_at: fn(place) { root_tests(root, place) },
    run: fn(place, input) { run_root(root, place, input) },
  )
}

fn root_tests(root: Root(context), place: Place) -> List(TestInfo) {
  collect_children(
    placed_children(root.children, place.source),
    list.append(place.groups, [root.name]),
    root.tags,
    [],
  )
  |> list.reverse
}

fn run_root(
  root: Root(context),
  place: Place,
  input: RunInput,
) -> RunRootParallelWithReporterResult {
  case
    selected_children(
      placed_children(root.children, place.source),
      list.append(place.groups, [root.name]),
      root.tags,
      input.keep,
    )
  {
    None -> nothing_ran(input)
    Some(children) ->
      parallel.run_suite(RunSuiteConfig(
        config: input.config,
        groups: place.groups,
        name: root.name,
        tags: root.tags,
        children: children,
        seed: root.seed,
        progress_reporter: input.progress_reporter,
        write: input.write,
        total: input.total,
        completed: input.completed,
        runner_before_each_test: list.map(
          input.before_each_test,
          typed_before_each_test,
        ),
        runner_after_each_test: list.map(
          input.after_each_test,
          typed_after_each_test,
        ),
        outer_setups: input.outer_setups,
      ))
  }
}

fn typed_before_each_test(
  hook: fn(TestInfo) -> Result(Nil, String),
) -> fn(TestInfo, context) -> Result(context, String) {
  fn(info, context) { run_before_each_test(hook, info, context) }
}

fn run_before_each_test(
  hook: fn(TestInfo) -> Result(Nil, String),
  info: TestInfo,
  context: context,
) -> Result(context, String) {
  result.replace(hook(info), context)
}

fn typed_after_each_test(
  hook: fn(TestInfo) -> Result(Nil, String),
) -> fn(TestInfo, context) -> Result(Nil, String) {
  fn(info, _context) { hook(info) }
}

/// The children with `source` as the source of each test, when it is set.
fn placed_children(
  children: List(Node(context)),
  source: Option(String),
) -> List(Node(context)) {
  case source {
    None -> children
    Some(source) -> list.map(children, node_with_source(_, source))
  }
}

fn node_with_source(node: Node(context), source: String) -> Node(context) {
  case node {
    Group(name: name, tags: tags, children: children) ->
      Group(
        name: name,
        tags: tags,
        children: list.map(children, node_with_source(_, source)),
      )
    Test(..) -> Test(..node, source: Some(source))
    BeforeAll(..) | BeforeEach(..) | AfterEach(..) | AfterAll(..) -> node
  }
}

fn collect_node(
  node: Node(context),
  groups: List(String),
  inherited_tags: List(String),
  tests_rev: List(TestInfo),
) -> List(TestInfo) {
  case node {
    Test(name: name, tags: tags, kind: kind, source: source, ..) -> [
      TestInfo(
        name: name,
        groups: groups,
        tags: list.append(inherited_tags, tags),
        kind: kind,
        source: source,
      ),
      ..tests_rev
    ]
    Group(name: name, tags: tags, children: children) ->
      collect_children(
        children,
        list.append(groups, [name]),
        list.append(inherited_tags, tags),
        tests_rev,
      )
    BeforeAll(..) | BeforeEach(..) | AfterEach(..) | AfterAll(..) -> tests_rev
  }
}

fn collect_children(
  children: List(Node(context)),
  groups: List(String),
  inherited_tags: List(String),
  tests_rev: List(TestInfo),
) -> List(TestInfo) {
  list.fold(children, tests_rev, fn(collected, child) {
    collect_node(child, groups, inherited_tags, collected)
  })
}

/// The children to run: all of them without `keep`, else the tests that
/// `keep` keeps, with the groups and hooks around them. `None` when `keep`
/// keeps no test.
fn selected_children(
  children: List(Node(context)),
  groups: List(String),
  tags: List(String),
  keep: Option(fn(TestInfo) -> Bool),
) -> Option(List(Node(context))) {
  case keep {
    None -> Some(children)
    Some(keep) -> kept_children(children, groups, tags, keep)
  }
}

fn kept_children(
  children: List(Node(context)),
  groups: List(String),
  tags: List(String),
  keep: fn(TestInfo) -> Bool,
) -> Option(List(Node(context))) {
  case filter_children(children, groups, tags, keep) {
    #(kept, True) -> Some(kept)
    #(_, False) -> None
  }
}

/// The children that `keep` keeps, and whether a test is among them.
fn filter_children(
  children: List(Node(context)),
  groups: List(String),
  inherited_tags: List(String),
  keep: fn(TestInfo) -> Bool,
) -> #(List(Node(context)), Bool) {
  let #(kept_rev, has_tests) =
    list.fold(children, #([], False), fn(filtered, child) {
      add_filtered(filtered, child, groups, inherited_tags, keep)
    })
  #(list.reverse(kept_rev), has_tests)
}

fn add_filtered(
  filtered: #(List(Node(context)), Bool),
  child: Node(context),
  groups: List(String),
  inherited_tags: List(String),
  keep: fn(TestInfo) -> Bool,
) -> #(List(Node(context)), Bool) {
  let #(kept_rev, has_tests) = filtered
  let #(kept, child_has_tests) =
    filter_node(child, groups, inherited_tags, keep)
  #(list.append(option.values([kept]), kept_rev), has_tests || child_has_tests)
}

fn filter_node(
  node: Node(context),
  groups: List(String),
  inherited_tags: List(String),
  keep: fn(TestInfo) -> Bool,
) -> #(Option(Node(context)), Bool) {
  case node {
    Test(name: name, tags: tags, kind: kind, source: source, ..) ->
      kept_test(
        node,
        keep(TestInfo(
          name: name,
          groups: groups,
          tags: list.append(inherited_tags, tags),
          kind: kind,
          source: source,
        )),
      )
    Group(name: name, tags: tags, children: children) ->
      kept_group(
        name,
        tags,
        filter_children(
          children,
          list.append(groups, [name]),
          list.append(inherited_tags, tags),
          keep,
        ),
      )
    BeforeAll(..) | BeforeEach(..) | AfterEach(..) | AfterAll(..) -> #(
      Some(node),
      False,
    )
  }
}

fn kept_test(
  node: Node(context),
  kept: Bool,
) -> #(Option(Node(context)), Bool) {
  case kept {
    True -> #(Some(node), True)
    False -> #(None, False)
  }
}

fn kept_group(
  name: String,
  tags: List(String),
  filtered: #(List(Node(context)), Bool),
) -> #(Option(Node(context)), Bool) {
  case filtered {
    #(children, True) -> #(
      Some(Group(name: name, tags: tags, children: children)),
      True,
    )
    #(_, False) -> #(None, False)
  }
}
