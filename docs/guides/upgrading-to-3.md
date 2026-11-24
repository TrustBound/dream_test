# Upgrade from Dream Test 2.x to 3.0.0

Dream Test 3.0.0 has breaking changes. Gherkin steps share a typed state in place of `world`, suites have one type whatever their context, `runner.run` returns a report, and hook failures have their own place in that report. Most projects need only a few of these changes, and the compiler finds most of them for you. This guide takes you through the upgrade in the order that works best: update the dependency, let the compiler list what broke, then fix one area at a time, each with the 2.x code next to the 3.0.0 code.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which steps you need](#which-steps-you-need)
- [Step 1: Update the dependency](#step-1-update-the-dependency)
- [Step 2: Read the compiler errors](#step-2-read-the-compiler-errors)
- [Step 3: Port the Gherkin step definitions](#step-3-port-the-gherkin-step-definitions)
- [Step 4: Update suites and the run report](#step-4-update-suites-and-the-run-report)
- [Step 5: Check the hook failures](#step-5-check-the-hook-failures)
- [Step 6: Update the reporters](#step-6-update-the-reporters)
- [Step 7: Update the tools that read the JSON report](#step-7-update-the-tools-that-read-the-json-report)
- [Step 8: Update parser code and feature files](#step-8-update-parser-code-and-feature-files)
- [Step 9: Update sandbox calls](#step-9-update-sandbox-calls)
- [Step 10: Check the polling helpers](#step-10-check-the-polling-helpers)
- [Step 11: Replace the removed items](#step-11-replace-the-removed-items)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

By the end of this guide, your project:

- Depends on Dream Test 3.0.0 and compiles.
- Has Gherkin steps that pass a typed state in place of `world`.
- Reads the run report, the hook failures and the new statuses where it used to read a list of results.
- Has tools and tests that expect the 3.0.0 JSON, the new test names of Gherkin examples, and the new error texts.

## Before you start

You need a project that uses Dream Test 2.x, and its tests passing on 2.x, so every failure after the upgrade is about the upgrade. Commit first, so you can compare.

Each 2.x example on this page has the label **Code at 2.1.3**: the code is a copy of a file at the 2.1.3 tag, and the link opens that file at the shown lines. The docs check compares each 2.x example with that file at the tag. Where no file at the 2.1.3 tag shows the old usage, the example shows the 2.1.3 source that makes the old behavior, and the text says so. Each 3.0.0 example is a tested snippet: the snippet tests compile it and run it.

## Which steps you need

Code that uses only `unit` and the runner with its default reporters compiles without changes, except for these items:

- the Gherkin step definitions
- `TestSuite` type annotations
- the runner test hooks
- filter predicates and other code that reads `full_name` of a `TestInfo` or a `TestResult`
- `runner.has_failures`
- code that uses the result of `runner.run` as a list
- each `unit_context.describe` call, which takes a `context.value(value)` in place of the start value
- the label `children:` of `describe` and `group`, and the field `children` of `types.Group`, which are now `tests:`

Most projects need only Steps 1 to 4. Do the steps in order. The first ones affect the most projects.

| Your code uses | What changed | Step |
|:---|:---|:---|
| Gherkin steps | Each step gets the scenario state and returns it. `world` is removed. `steps.when_` and `steps.then_` are now `steps.when` and `steps.then`. `feature.to_test_suite` and `FeatureConfig` are removed: use `steps.feature_suite`. | [Step 3](#step-3-port-the-gherkin-step-definitions) |
| Suites, the runner, `parallel` | A suite has the type `TestSuite` from `dream_test/suite`, with no type parameter. The runner test hooks get only the `TestInfo`. `runner.run` returns a `types.RunReport`. `runner.has_failures` is now `types.failed`. `runner.exit_on_failure` exits with status 1 in more cases, also for a run with no test (`runner.allow_no_tests()` allows one). `runner.silent` still writes errors. `types.Root` is now `types.Tree`. The `parallel` names say "tree", and their label `suite:` is now `tree:`. `RunTreeParallelWithReporterConfig` has the new field `outer_setups`. `unit_context.describe` takes a `context.value(value)` in place of the start value. The label `children` of `describe` and `group` and the field `children` of `types.Group` are now `tests`, and `types.Tree` has `initial` in place of `seed`. `AssertionResult` has the new variant `AssertionPending`. The discovery errors have new texts. | [Step 4](#step-4-update-suites-and-the-run-report) |
| Hooks | A failed setup hook gives `SetupFailed`. A failed teardown hook goes into the run report, not into the test results. | [Step 5](#step-5-check-the-hook-failures) |
| Reporters | The functions that format a whole run take a `RunReport`. `GherkinScenario` has the fields `scenario_id`, `feature` and `rule`. The progress event API is removed. `ResultsReporter` has the new variant `Custom`, and `FailurePayload` the new variant `StepFailure`. | [Step 6](#step-6-update-the-reporters) |
| The JSON report | The JSON report has schema version `2.0`. | [Step 7](#step-7-update-the-tools-that-read-the-json-report) |
| The Gherkin parser and syntax tree, `.feature` files | The parser follows the official Gherkin grammar, and parse errors are typed. | [Step 8](#step-8-update-parser-code-and-feature-files) |
| `sandbox` | `sandbox.run_isolated` takes the function and its input. | [Step 9](#step-9-update-sandbox-calls) |
| `process.await_ready`, `process.await_some` | No code change. They can time out sooner. | [Step 10](#step-10-check-the-polling-helpers) |
| Removed items | Each one has a replacement, or needs none. | [Step 11](#step-11-replace-the-removed-items) |

## Step 1: Update the dependency

Change the Dream Test line in the `[dev-dependencies]` of your `gleam.toml`:

```toml
[dev-dependencies]
dream_test = ">= 3.0.0 and < 4.0.0"
```

Then download it:

```sh
gleam deps update dream_test
```

## Step 2: Read the compiler errors

Run `gleam test`. The compiler stops before any test runs, and lists what no longer compiles. Two errors almost every Gherkin project sees first are a step that uses `world`, and a suite annotated with the old `TestSuite(Nil)`.

For a 2.x step that imports `dream_test/gherkin/world` and calls `put(context.world, "cart", 3)`, the compiler says:

### The compiler error of a step that uses world <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_upgrading_world_error.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
warning: Unused function argument
  ┌─ build/compile_errors/upgrade_world/src/upgrade_world.gleam:8:24
  │
8 │ pub fn step_have_items(context: StepContext) {
  │                        ^^^^^^^ This argument is never used

Hint: You can ignore it with an underscore: `_context`.

error: Unknown module
  ┌─ build/compile_errors/upgrade_world/src/upgrade_world.gleam:6:1
  │
6 │ import dream_test/gherkin/world.{put}
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

No module has been found with the name `dream_test/gherkin/world`.

error: Unknown variable
  ┌─ build/compile_errors/upgrade_world/src/upgrade_world.gleam:9:3
  │
9 │   put(context.world, "cart", 3)
  │   ^^^

The name `put` is not in scope here.

error: Unknown record field
  ┌─ build/compile_errors/upgrade_world/src/upgrade_world.gleam:9:15
  │
9 │   put(context.world, "cart", 3)
  │               ^^^^^ This field does not exist

The value being accessed has this type:

    StepContext

It has these accessible fields:

    .captures
    .doc_string
    .scenario_id
    .table

```

The module is gone, so `put` is unknown, and `StepContext` has no `world` field. Its fields are now `captures`, `doc_string`, `scenario_id` and `table`. [Step 3](#step-3-port-the-gherkin-step-definitions) replaces `world` with the scenario state.

For a 2.x suite function with the return type `TestSuite(Nil)`, imported from `dream_test/types`, the compiler says:

### The compiler error of the old TestSuite type <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_upgrading_suite_type_error.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
warning: Unused imported module
  ┌─ build/compile_errors/upgrade_suite_type/src/upgrade_suite_type.gleam:6:1
  │
6 │ import dream_test/types.{type TestSuite}
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ This imported module is never used

Hint: You can safely remove it.

error: Unknown module type
  ┌─ build/compile_errors/upgrade_suite_type/src/upgrade_suite_type.gleam:6:26
  │
6 │ import dream_test/types.{type TestSuite}
  │                          ^^^^^^^^^^^^^^

The module `dream_test/types` does not have a `TestSuite` type.

error: Unknown type
  ┌─ build/compile_errors/upgrade_suite_type/src/upgrade_suite_type.gleam:9:19
  │
9 │ pub fn tests() -> TestSuite(Nil) {
  │                   ^^^^^^^^^^^^^^

The type `TestSuite` is not defined or imported in this module.

```

`TestSuite` now lives in `dream_test/suite`, with no type parameter. [Step 4](#step-4-update-suites-and-the-run-report) shows the change. Fix the errors step by step, from Step 3 on, and run `gleam test` after each step. When it compiles, the remaining steps are about behavior: read them even when the compiler is happy.

## Step 3: Port the Gherkin step definitions

In 2.x, steps shared data through `world`, a key/value store in an ETS table. Each scenario made one atom that the BEAM never freed. In 3.0.0, each scenario has one typed state value. A `given` or `when` step gets the state and returns the new state. A `then` step gets the state and returns an assertion. A `then` step cannot change the state.

### Steps get and return the state

Give the initial state to `steps.new`. Register each step with the function for its phase: `given`, `when` or `then`.

#### 2.x: steps that use `world` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_hero.gleam#L1-L54"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{but, feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

fn step_have_items(context: StepContext) {
  let count = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", count)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_should_have(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_should_have)

  feature("Shopping Cart", steps, [
    scenario("Adding items to cart", [
      given("I have 3 items in my cart"),
      when("I add 2 more items"),
      then("I should have 5 items total"),
      but("I should have 5 items total"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

#### 3.0.0: steps that use a typed state <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_steps.gleam#L1-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{but, feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

fn step_have_items(_cart: Int, context: StepContext) {
  get_int(context.captures, 0)
}

fn step_add_items(cart: Int, context: StepContext) {
  use to_add <- result.try(get_int(context.captures, 0))
  Ok(cart + to_add)
}

fn step_should_have(cart: Int, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given("I have {int} items in my cart", step_have_items)
    |> steps.when("I add {int} more items", step_add_items)
    |> steps.then("I should have {int} items total", step_should_have)

  feature("Shopping Cart", steps, [
    scenario("Adding items to cart", [
      given("I have 3 items in my cart"),
      when("I add 2 more items"),
      then("I should have 5 items total"),
      but("I should have 5 items total"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

Look for these in your code:

- `import dream_test/gherkin/world`: remove it.
- `put(context.world, ...)`: return the new state from the step in its place.
- `get_or(context.world, ...)` and `get(context.world, ...)`: read the first argument of the step in their place.
- `steps.new()`: give the initial state, for example `steps.new(initial: 0)`.
- `steps.step`, `steps.when_` and `steps.then_`: use `steps.given`, `steps.when` or `steps.then`.
- `result.unwrap` on a capture: use `result.try`. Then a wrong capture fails the scenario with a clear message.

If `world` held a resource for all scenarios, for example a server or a connection pool, make the registry with `steps.new_with_setup`. Its setup runs one time, and each scenario starts from its value. To share one setup between several Features, give them to `steps.to_suite` as `steps.SuiteTest` values. See [A setup for all scenarios](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md#step-6-start-a-server-once-for-all-scenarios).

### A record for more than one value

A scenario that kept more than one `world` key needs a record as its state. Each step returns a copy of the record with the changed fields.

#### 2.x: a step that writes two `world` keys <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/shopping_cart/test/steps/cart.gleam#L52-L72"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn step_try_add_product(
  context: StepContext,
) -> Result(AssertionResult, String) {
  let quantity = get_int(context.captures, 0) |> result.unwrap(0)
  let product =
    get_string(context.captures, 1) |> result.unwrap("") |> lookup_product()
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case cart.add_item(the_cart, product, quantity) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      put(context.world, "last_error", "")
      Ok(succeed())
    }

    Error(e) -> {
      put(context.world, "last_error", add_item_error_to_string(e))
      Ok(succeed())
    }
  }
}
```

#### 3.0.0: a step that changes two record fields <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_shop.gleam#L11-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Shop {
  Shop(cart: Dict(String, Int), last_error: String, order_id: String)
}

fn empty_shop() -> Shop {
  Shop(cart: dict.new(), last_error: "", order_id: "")
}

fn add_item(
  cart: Dict(String, Int),
  product: String,
  quantity: Int,
) -> Result(Dict(String, Int), String) {
  case quantity > 0 {
    True ->
      Ok(
        dict.upsert(cart, product, fn(current) {
          option.unwrap(current, 0) + quantity
        }),
      )
    False -> Error("invalid quantity")
  }
}

fn step_try_add_product(
  shop: Shop,
  context: StepContext,
) -> Result(Shop, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product <- result.try(get_word(context.captures, 1))

  case add_item(shop.cart, product, quantity) {
    Ok(updated) -> Ok(Shop(..shop, cart: updated, last_error: ""))
    Error(message) -> Ok(Shop(..shop, last_error: message))
  }
}
```

### The scenario id

`StepContext` has a `scenario_id` field. It replaces `world.scenario_id(context.world)`.

The id is different. In 2.x it was the name path, for example `"Shopping Cart::Adding items"`, and two scenarios with the same name had the same id. In 3.0.0 it ends with `#` and a number, for example `"Shopping Cart::Adding items#12"`, so it is unique in the run. The number changes between runs, so do not use the id to key data that you keep between runs. The JSON report writes the same id in `"kind": "gherkin:<id>"`. A check that compares the whole id must now compare only the start.

No step at the 2.1.3 tag reads the id. The 2.1.3 snippet below makes a world by hand and reads its id with the same function.

#### 2.x: read the scenario id from `world` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/world_scenario_id.gleam"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/world

pub fn main() {
  let w = world.new_world("example_scenario")
  let id = world.scenario_id(w)
  world.cleanup(w)
  id
}
```

#### 3.0.0: read the scenario id from the context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_shop.gleam#L48-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn step_place_order(shop: Shop, context: StepContext) -> Result(Shop, String) {
  Ok(Shop(..shop, order_id: context.scenario_id))
}
```

### One pattern, one phase

`steps.step` is removed. It registered a pattern for every phase. Register each pattern with `given`, `when` or `then`. To use one pattern in two phases, register it two times. A function that returns a registry names the state type, for example `StepRegistry(Shop)`.

#### 2.x: a register function with `steps.step` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/shopping_cart/test/steps/cart.gleam#L19-L26"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> steps.step("I have an empty cart", step_empty_cart)
  |> steps.step("I add {int} {word} to the cart", step_add_product)
  |> steps.step("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.step("I update the {word} quantity to {int}", step_update_quantity)
  |> steps.step("I remove {word} from the cart", step_remove_product)
}
```

#### 3.0.0: a register function with one phase for each pattern <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_shop.gleam#L52-L61"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn register(registry: StepRegistry(Shop)) -> StepRegistry(Shop) {
  registry
  |> steps.given("I have an empty cart", step_empty_cart)
  |> steps.when("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.when("I place the order", step_place_order)
  |> steps.then("the cart has {int} {word}", step_cart_has)
  |> steps.then("the error is {string}", step_error_is)
  |> steps.then("the order id starts with {string}", step_order_id_starts)
}
```

In 2.x, a second definition of a pattern replaced the first with no message. In 3.0.0, a pattern registered two times in one phase is an error. The first definition stays. Each scenario that uses the registry fails with `Duplicate step definition: ...`. Call `steps.validate(registry)` to find each duplicate. The same pattern in two phases is not a duplicate.

### Code that looks up steps

`steps.find_step` takes a `StepPhase` (`GivenPhase`, `WhenPhase` or `ThenPhase`) in place of a `StepKeyword`. `step_trie.insert` and `step_trie.lookup` take a `StepPhase` in place of a keyword `String`. `step_trie.insert` returns a `Result`, because a second handler for one phase and pattern is an error. The trie has no `"*"` handler.

#### 2.x: find a step by its keyword <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_steps_registry.gleam#L25-L35"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("can extract an int capture", fn() {
      let registry = steps.new() |> given("I have {int} items", step_pass)

      use matched <- result.try(find_step(registry, Given, "I have 3 items"))
      use count <- result.try(get_int(matched.captures, 0))

      count
      |> should
      |> be_equal(3)
      |> or_fail_with("expected captured int to be 3")
    }),
```

#### 3.0.0: find a step by its phase <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_lookup.gleam#L15-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("can extract an int capture", fn() {
      let registry =
        steps.new(initial: 0) |> given("I have {int} items", step_count)

      use matched <- result.try(find_step(
        registry,
        GivenPhase,
        "I have 3 items",
      ))
      use count <- result.try(get_int(matched.captures, 0))

      count
      |> should
      |> be_equal(3)
      |> or_fail_with("expected captured int to be 3")
    }),
```

#### 2.x: a step trie with keyword strings <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/step_trie.gleam#L46-L75"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("lookup finds the most specific pattern and captures typed values", fn() {
      let trie =
        step_trie.new()
        |> step_trie.insert(
          keyword: "Given",
          pattern: "I have an empty cart",
          handler: "empty",
        )
        |> step_trie.insert(
          keyword: "Given",
          pattern: "I have {int} items",
          handler: "count",
        )
        |> step_trie.insert(
          keyword: "Then",
          pattern: "the total is ${float}USD",
          handler: "total_usd",
        )

      step_trie.lookup(trie, "Then", "the total is $19.99USD")
      |> should
      |> be_equal(
        Some(
          step_trie.StepMatch(handler: "total_usd", captures: [
            step_trie.CapturedFloat(19.99),
          ]),
        ),
      )
      |> or_fail_with("expected float capture for $19.99USD")
    }),
```

#### 3.0.0: a step trie with phases <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_lookup.gleam#L31-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("lookup finds the most specific pattern and captures typed values", fn() {
      use trie <- result.try(
        step_trie.new()
        |> step_trie.insert(
          phase: GivenPhase,
          pattern: "I have an empty cart",
          handler: "empty",
        ),
      )
      use trie <- result.try(step_trie.insert(
        trie,
        phase: GivenPhase,
        pattern: "I have {int} items",
        handler: "count",
      ))
      use trie <- result.try(step_trie.insert(
        trie,
        phase: ThenPhase,
        pattern: "the total is ${float}USD",
        handler: "total_usd",
      ))

      step_trie.lookup(trie, ThenPhase, "the total is $19.99USD")
      |> should
      |> be_equal(
        Some(
          step_trie.StepMatch(handler: "total_usd", captures: [
            step_trie.CapturedFloat(19.99),
          ]),
        ),
      )
      |> or_fail_with("expected float capture for $19.99USD")
    }),
```

#### 3.0.0: find a duplicate step definition <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_lookup.gleam#L64-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("validate reports a pattern defined twice in one phase", fn() {
      steps.new(initial: 0)
      |> given("I have {int} items", step_count)
      |> given("I have {int} items", step_count)
      |> steps.validate
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("expected a duplicate step definition error")
    }),
```

### Other Gherkin step changes

| 2.x | 3.0.0 |
|---|---|
| `StepHandler` type | `StepDefinition(state)`: `Action` for `given` and `when`, `Check` for `then` |
| `InlineStep(keyword: "When", text: "I add 3")` | `InlineStep(keyword: gherkin_types.When, text: "I add 3")`. The `given`, `when`, `then`, `and` and `but` helpers do not change. |
| `let d: FeatureDiscovery = discover.with_registry(found, steps)` | `let d: RunnableDiscovery(Int) = discover.with_registry(found, steps)` |
| `discover.to_suite` on a `FeatureDiscovery` | Call `discover.with_registry` first. `to_suite` takes only a `RunnableDiscovery`. |
| `FeatureConfig` | Removed. Use `steps.feature_suite(registry:, feature:)`. |
| A `discover.features` pattern that matched no files gave an empty suite, and the run passed. | `to_suite` gives one failing test, `No feature files match the pattern "<pattern>"`, tagged `no-feature-files`. `load` gives the error `parser.NoMatchingFeatureFiles(pattern)`. Fix the pattern. |
| A `discover.features` pattern that cannot be searched, for example `features/{a.feature`, crashed the test run. | `to_suite` gives one failing test, `Cannot search for feature files with the pattern "<pattern>": <reason>`, tagged `invalid-feature-pattern`. `load` gives the error `parser.InvalidFeatureFilePattern(pattern, reason)`. Fix the pattern. |
| `steps.given(registry, pattern, handler: f)` | `steps.given` and `steps.when` take `action: f`, and `steps.then` takes `check: f`. Code that does not write the label does not change. |

The usual chain `discover.features(...) |> discover.with_registry(steps) |> discover.to_suite(...)` does not change.

### `discover.list_files` returns a `Result`

`discover.list_files` returns `Result(List(String), parser.FeatureFileError)`. A pattern that cannot be searched, for example `features/{a.feature`, gives `Error(parser.InvalidFeatureFilePattern(pattern, reason))`. A pattern that matches no files gives `Ok([])`. In 2.x, it returned `List(String)`, and a pattern that cannot be searched stopped the test run with a crash.

#### 2.x: `list_files` returns a list <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/discover_loading.gleam#L7-L13"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("list_files returns matching .feature file paths", fn() {
      discover.features("test/*.feature")
      |> discover.list_files()
      |> should
      |> contain("test/cart.feature")
      |> or_fail_with("expected list_files to include test/cart.feature")
    }),
```

#### 3.0.0: `list_files` returns a `Result` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/discover_loading.gleam#L7-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("list_files returns matching .feature file paths", fn() {
      discover.features("test/*.feature")
      |> discover.list_files()
      |> should
      |> be_ok()
      |> contain("test/cart.feature")
      |> or_fail_with("expected list_files to include test/cart.feature")
    }),
```

### `feature.to_test_suite` and `FeatureConfig` are removed

`feature.to_test_suite` and `FeatureConfig` are removed. A suite from one parsed Feature is `steps.feature_suite(registry:, feature:)`. Its top-level group is the Feature, as in 2.x. Remove the import `dream_test/gherkin/feature.{FeatureConfig, to_test_suite}`, and import `steps.feature_suite` in its place: `import dream_test/gherkin/steps.{feature_suite}`.

#### 2.x: a suite from `feature.to_test_suite` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_file.gleam#L45-L50"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
  // Parse the .feature file
  let assert Ok(feature) = parser.parse_file("test/cart.feature")

  // Convert to TestSuite and run
  let config = FeatureConfig(feature: feature, step_registry: steps)
  to_test_suite(config)
```

#### 3.0.0: a suite from `steps.feature_suite` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_file.gleam#L43-L47"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // Parse the .feature file
  let assert Ok(feature) = parser.parse_file("test/cart.feature")

  // Make a suite from the Feature
  feature_suite(registry: steps, feature: feature)
```

### How step text matches a pattern

In 3.0.0, step text and step patterns are split into words in the same way: at spaces, with a double-quoted run kept in one word. A quoted run starts at a double quote at the start of a word, also after `(` or `[`. It ends at a double quote before a space, the end of the text, or one of `,` `.` `)` `]` `;` `:` `!` `?`. So `"apple", "banana"` is two words, and the quote in `O"Brien` or `5"` is an ordinary character. A pattern without placeholders always matches its own text. In 2.x, the step text was also split where digits meet other characters, but the pattern was not.

| 2.x | 3.0.0 | What to do |
|---|---|---|
| `the user is {word}` did not match `the user is user42`. | It matches and captures `user42`. | Nothing. |
| A pattern without placeholders, such as `I enable 2FA` or `I click "Save changes"`, did not match its own text. | It matches. | Nothing. |
| A space in the pattern did not need a space in the text: `$ {float}` matched `$19.99`. | A space in the pattern must be a space in the text. | Write the pattern as the text is written, for example `${float}`. |
| `{float}` needed a `.`: `total {float}` did not match `total 20`. | `{float}` matches a number as Cucumber reads it, such as `20`, `.5` or `1e5`. With `total {word}` and `total {float}`, the text `total 20` now matches `{float}`. | Check steps that use `{word}` or `{}` for numbers next to a `{float}` step. |
| `{word}` matched a quoted run with spaces, for example `"Save changes"`. | `{word}` matches only text with no space. | Use `{string}`, or `{}` to keep the quotes. |
| With `I have {int} items` and `I have 5 apples`, the text `I have 5 items` matched no step. Lookup took the literal word `5` and did not go back. | Lookup goes back and tries the next pattern, so the text matches `I have {int} items`. When two patterns match, a literal word wins over a placeholder. | Nothing. |
| `step_trie.parse_step_pattern` gave a flat `List(StepSegment)` with `LiteralWord`. | It gives one `List(StepSegment)` for each word, with `LiteralText`. | Read the segments of each word. |
| `step_trie.tokenize_step_text("$19.99USD")` gave `["$", "19.99", "USD"]`. | It gives `["$19.99USD"]`. | Nothing, unless you call it. |

## Step 4: Update suites and the run report

`runner.run` returns a `types.RunReport`, not `List(TestResult)`. The report holds the test results, the hook failures and the results reporters that crashed. Use `types.report_tests(report)` to get the test results. Use `types.failed(report)` to find out if the run failed.

### Suites have one type, whatever their context

`types.TestSuite(context)` is removed. A suite now has the type `TestSuite` from the new module `dream_test/suite`, with no type parameter. Each tree of a suite keeps its context inside the suite, so one `runner.new` takes suites with different contexts: `unit` suites, `unit_context` suites and Gherkin features. `runner.RunBuilder` has no type parameter too. Change each `TestSuite(Nil)` or `TestSuite(context)` annotation to `TestSuite`, and import it from `dream_test/suite`.

#### 2.x: a suite with the type `TestSuite(Nil)` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/parallel_with_reporter.gleam#L5-L13"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}

pub fn suite() -> TestSuite(Nil) {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}
```

#### 3.0.0: suites with the type `TestSuite`, in one run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/suite_type.gleam#L1-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import dream_test/unit_context

pub fn suite() -> TestSuite {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn context_suite() -> TestSuite {
  unit_context.describe("context suite", context.value(41), [
    unit_context.it("gets 41", fn(number: Int) {
      number
      |> should
      |> be_equal(41)
      |> or_fail_with("expected 41")
    }),
  ])
}

pub fn main() {
  runner.new([suite(), context_suite()])
  |> runner.run()
}
```

### `runner.has_failures` is now `types.failed`

`types.failed` is also `True` when a teardown hook failed and every test passed, when a setup stopped, and when a `reporter_types.Custom` reporter crashed.

#### 2.x: check a run with `runner.has_failures` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/runner/has_failures.gleam#L1-L30"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("has_failures", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn failing_suite() {
  describe("failing suite", [
    it("fails", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional failure for has_failures example")
    }),
  ])
}

pub fn main() {
  let results = runner.new([failing_suite()]) |> runner.run()

  results
  |> runner.has_failures()
  |> should
  |> be_equal(True)
  |> or_fail_with("expected failures to be present")
}
```

#### 3.0.0: check a run with `types.failed` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/run_report.gleam#L1-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("types.failed", [
    it("is True after a failed test", fn() {
      let report = runner.new([failing_suite()]) |> runner.run()

      report
      |> types.failed()
      |> should
      |> be_equal(True)
      |> or_fail_with("expected failures to be present")
    }),
  ])
}

fn failing_suite() {
  describe("failing suite", [
    it("fails", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional failure for the types.failed example")
    }),
  ])
}
```

### `exit_on_failure` exits with status 1 in more cases

In 2.x, `runner.exit_on_failure` looked only at the test results. In 3.0.0, it also gives exit status 1 in these cases, also when every test passed:

- a teardown hook failed
- a setup stopped (`SetupStopped`)
- the `render` function of a `reporter_types.Custom` reporter crashed
- the run ran no test, for example a filter that keeps nothing or `runner.new([])`
- coverage failed

A run with no test passed in 2.x. In 3.0.0, it fails, and the report ends with a `No tests ran` line. A skipped or pending test is a test that ran. If a runner of yours is empty on purpose, pipe it through `runner.allow_no_tests()` before `runner.run()`, as [When a filter keeps nothing](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md#when-a-filter-keeps-nothing) shows.

`types.failed` is `True` for a report with no test result, also one from `types.run_report(tests: [], ...)` or `parallel.run_tree_parallel`. `types.allow_no_tests(report)` makes such a report pass in a custom runner.

[Exit status](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md#step-6-decide-the-exit-status) lists every case.

### `runner.silent` still writes errors

In 2.x, `runner.silent` dropped all output. In 3.0.0, it drops the normal output only: progress, results reports and the coverage report. It still writes three kinds of error to the standard error stream: the error of a `--only` path that selects no test, the `Results reporter failed` error of a `reporter_types.Custom` reporter that crashed, and a coverage error, for example a total below `coverage.minimum_percent`.

### Runner test hooks: only the `TestInfo`, with `groups`

A `before_each_test` or `after_each_test` hook gets only the `TestInfo` of the test: `fn(TestInfo) -> Result(Nil, String)`. It does not get the context, and it cannot change the context, because the suites of one run can have different context types. Remove the context argument, and return `Ok(Nil)`.

`TestResult` and `TestInfo` hold `groups`, the names of the groups around the test. The `full_name` field is removed. `types.full_name(groups, name)` gives the old list. The JSON report still writes `full_name` as the full list.

#### 2.x: a runner hook that reads `info.full_name` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/runner/runner_hooks.gleam#L36-L39"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn before_each_test_hook(info: TestInfo, ctx: Nil) -> Result(Nil, String) {
  io.println("test: " <> string.join(info.full_name, " > "))
  Ok(ctx)
}
```

#### 3.0.0: a runner hook that reads `info.groups` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/test_names.gleam#L33-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn before_each_test_hook(info: TestInfo) -> Result(Nil, String) {
  io.println("test: " <> test_label(info))
  Ok(Nil)
}

fn test_label(info: TestInfo) -> String {
  types.full_name(info.groups, info.name)
  |> string.join(" > ")
}
```

### `types.Root` is now `types.Tree`

This change affects only code that uses `types.Root` or `dream_test/parallel` directly. A `Root` was one tree of tests, not a whole suite, so it has a new name. `types.Root` is now `types.Tree`, and `types.root` is now `types.tree`. A tree is one top-level group with its tests and one context. A suite holds one or more trees. The `parallel` functions take the tree with the label `tree:`. In 2.x the label was `suite:`.

#### 2.x: the tree with the label `suite:` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/parallel_with_reporter.gleam#L32-L44"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
  let parallel_result =
    parallel.run_root_parallel_with_reporter(
      parallel.RunRootParallelWithReporterConfig(
        config: parallel.default_config(),
        suite: suite(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
      ),
    )
```

#### 3.0.0: a tree from `types.tree` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/parallel_with_reporter.gleam#L5-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/types.{type Tree}
import dream_test/unit.{it}
import gleam/option.{Some}

pub fn tree() -> Tree(Nil) {
  types.tree("suite", Nil, [
    it("passes", fn() { Ok(succeed()) }),
  ])
}
```

#### 3.0.0: the tree with the label `tree:` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/parallel_with_reporter.gleam#L25-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let parallel_result =
    parallel.run_tree_parallel_with_reporter(
      parallel.RunTreeParallelWithReporterConfig(
        config: parallel.default_config(),
        tree: tree(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
        outer_setups: [],
      ),
    )
```

### The `parallel` names say "tree"

This change affects only code that uses `dream_test/parallel` directly. The names that said "root" now say "tree":

- `run_root_parallel` is now `run_tree_parallel`.
- `run_root_parallel_with_reporter` is now `run_tree_parallel_with_reporter`.
- `RunRootParallelWithReporterConfig` is now `RunTreeParallelWithReporterConfig`.
- `RunRootParallelWithReporterResult` is now `RunTreeParallelWithReporterResult`.

#### 2.x: a call to `run_root_parallel` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/parallel_direct.gleam#L14-L17"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
      parallel.run_root_parallel(parallel.default_config(), suite)
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
```

#### 3.0.0: a call to `run_tree_parallel` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/parallel_direct.gleam#L15-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      parallel.run_tree_parallel(parallel.default_config(), tree)
      |> types.report_tests
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
```

### Running a suite with `parallel`

`parallel.run_tree_parallel` returns a `RunReport`. The typed `parallel` functions take a `types.Tree(context)`. `unit.describe` gives a `TestSuite` now, so build the tree with `types.tree`.

#### 2.x: `run_root_parallel` returns a list <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/parallel_direct.gleam#L1-L20"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a suite and return a list of results", fn() {
      let suite =
        describe("Suite", [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_root_parallel(parallel.default_config(), suite)
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```

#### 3.0.0: `run_tree_parallel` returns a report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/parallel_direct.gleam#L1-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a tree and return a report of the results", fn() {
      let tree =
        types.tree("Suite", Nil, [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_tree_parallel(parallel.default_config(), tree)
      |> types.report_tests
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```

### `RunTreeParallelWithReporterConfig` has `outer_setups`

This change affects only code that calls `parallel.run_tree_parallel_with_reporter` (in 2.x `run_root_parallel_with_reporter`) directly. `RunTreeParallelWithReporterConfig` has a new field, `outer_setups`. Give it `[]`. Its fields `runner_before_each_test` and `runner_after_each_test` are `List(fn(TestInfo) -> Result(Nil, String))`. In 2.x the hooks also got the context. `RunTreeParallelWithReporterResult` has two new fields, `hook_failures` and `outer_setups`. This example also uses the new progress API. See [Progress events](#progress-events).

#### 2.x: a run with a progress reporter <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/parallel_with_reporter.gleam#L1-L62"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}

pub fn suite() -> TestSuite(Nil) {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn write_if_some(text: Option(String), write: fn(String) -> Nil) {
  case text {
    Some(s) -> write(s)
    None -> Nil
  }
}

pub fn main() {
  let total = 1
  let completed = 0

  let reporter = progress.new()
  let write = fn(_s: String) { Nil }

  progress.handle_event(reporter, reporter_types.RunStarted(total: total))
  |> write_if_some(write)

  let parallel_result =
    parallel.run_root_parallel_with_reporter(
      parallel.RunRootParallelWithReporterConfig(
        config: parallel.default_config(),
        suite: suite(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
      ),
    )
  let parallel.RunRootParallelWithReporterResult(
    results: results,
    completed: completed_after_suite,
    progress_reporter: _progress_reporter,
  ) = parallel_result

  progress.handle_event(
    reporter,
    reporter_types.RunFinished(
      completed: completed_after_suite,
      total: total,
      results: results,
    ),
  )
  |> write_if_some(write)

  results
}
```

#### 3.0.0: a run with a progress reporter <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/parallel_with_reporter.gleam#L1-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/reporters/summary
import dream_test/types.{type Tree}
import dream_test/unit.{it}
import gleam/option.{Some}

pub fn tree() -> Tree(Nil) {
  types.tree("suite", Nil, [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let total = 1
  let completed = 0

  let reporter = progress.new()
  let write = fn(_s: String) { Nil }

  progress.line(reporter, progress.RunStartedProgress(total: total))
  |> write

  let parallel_result =
    parallel.run_tree_parallel_with_reporter(
      parallel.RunTreeParallelWithReporterConfig(
        config: parallel.default_config(),
        tree: tree(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
        outer_setups: [],
      ),
    )
  let parallel.RunTreeParallelWithReporterResult(
    results: results,
    hook_failures: hook_failures,
    completed: completed_after_suite,
    progress_reporter: _progress_reporter,
    outer_setups: _outer_setups,
  ) = parallel_result

  let report =
    types.run_report(
      tests: results,
      hook_failures: hook_failures,
      reporter_crashes: [],
    )

  // Count failed teardown hooks and stopped setups apart.
  let counts = summary.count(report)

  progress.line(
    reporter,
    progress.RunFinishedProgress(
      completed: completed_after_suite,
      total: total,
      teardown_failed: counts.teardown_failed,
      setup_stopped: counts.setup_stopped,
    ),
  )
  |> write

  report
}
```

### Suites built by hand

This change affects only code that builds `types.Root` or `types.Node` values directly, for example a generator of table tests. `Root` is now `Tree` (see [`types.Root` is now `types.Tree`](#typesroot-is-now-typestree)). `Tree` holds the fields of its top-level group: `Tree(initial:, name:, tags:, tests:)`. The `run` field of `Test`, `BeforeAll`, `BeforeEach`, `AfterEach` and `AfterAll` is a `types.Callback`. Use `NoInput(f)` for a function with no argument. Use `WithInput(f)` for a function that takes the context. Give the `Tree` to `suite.from_tree` to get a `TestSuite` for the runner.

No file at the 2.1.3 tag builds a table of tests by hand. The 2.1.3 source of `unit.describe` and `unit.it` builds the same values: a `Root` with `seed` and `tree`, and a `Test` whose `run` takes the context.

#### 2.x: `unit.describe` builds a `Root` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/unit.gleam#L125-L130"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn describe(
  name name: String,
  children children: List(UnitNode),
) -> TestSuite(Nil) {
  Root(seed: Nil, tree: Group(name: name, tags: [], children: children))
}
```

#### 2.x: `unit.it` builds a `Test` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/unit.gleam#L248-L260"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn it(
  name name: String,
  run run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_nil: Nil) { run() },
    timeout_ms: None,
    source: None,
  )
}
```

#### 3.0.0: a table of tests built by hand <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/hand_built_suite.gleam#L1-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type Node, BeforeAll, NoInput, Test, Tree, Unit, WithInput,
}
import gleam/int
import gleam/list
import gleam/option.{None}

fn doubling_cases() -> List(#(Int, Int)) {
  [#(1, 2), #(2, 4), #(21, 42)]
}

fn check_tables() -> Result(Nil, String) {
  Ok(Nil)
}

fn doubling_test(pair: #(Int, Int)) -> Node(Nil) {
  let #(input, expected) = pair
  Test(
    name: "doubles " <> int.to_string(input),
    tags: [],
    kind: Unit,
    run: WithInput(fn(_context: Nil) {
      input * 2
      |> should
      |> be_equal(expected)
      |> or_fail_with("wrong double")
    }),
    timeout_ms: None,
    source: None,
  )
}

pub fn tests() -> TestSuite {
  suite.from_tree(
    Tree(initial: Nil, name: "doubling", tags: [], tests: [
      BeforeAll(NoInput(check_tables)),
      ..list.map(doubling_cases(), doubling_test)
    ]),
  )
}
```

### `unit_context.describe` takes a context, and `children` is now `tests`

`unit_context.describe` takes a `dream_test/context.Context` in place of the start value. Put the start value in `context.value`: `unit_context.describe("counter", 0, [...])` is now `unit_context.describe("counter", context.value(0), [...])`, with `import dream_test/context`. With labels, `describe(name:, seed:, children:)` is now `describe(name:, context:, tests:)`. A start value that a setup makes and a teardown stops goes in `context.setup(setup, teardown:)` (see [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md#step-3-get-the-context-from-a-setup)).

The label `children` is now `tests` in `unit.describe`, `unit.group`, `unit_context.describe`, `unit_context.group`, `suite.new`, `types.tree`, `steps.to_suite` and `steps.Group`. The field `children` of `types.Group` is now `tests` too, so a pattern or a record update with the label `children:` changes in the same way. A call without labels, such as `unit.describe("math", [...])`, does not change. Change only the label.

The start value of `types.tree` and the field of `types.Tree` have the label `initial` in place of `seed`, as in `steps.new(initial:)`: `types.tree(name:, initial:, tests:)`.

#### 2.x: `unit_context.describe` with the label `seed` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/unit_context.gleam#L115-L121"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn describe(
  name name: String,
  seed seed: context,
  children children: List(ContextNode(context)),
) -> TestSuite(context) {
  Root(seed: seed, tree: Group(name: name, tags: [], children: children))
}
```

#### 3.0.0: `unit_context.describe` with a context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/describe_context.gleam#L6-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  unit_context.describe(name: "a counter", context: context.value(41), tests: [
    unit_context.it("starts from the value of the context", fn(count: Int) {
      count
      |> should
      |> be_equal(41)
      |> or_fail_with("expected the start value 41")
    }),
  ])
}
```

### `AssertionResult` has `AssertionPending`

This change affects only code that has a `case` on a `types.AssertionResult`. The new variant `AssertionPending` is the result of a pending test (`unit.pending`). Add a branch for it. Its test status is `Pending`.

#### 2.x: a `case` on `AssertionResult` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/parallel.gleam#L2092-L2111"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn assertion_to_status_and_failures(
  result: AssertionResult,
  inherited_failures_rev: List(AssertionFailure),
  setup_failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  case result {
    AssertionOk -> #(
      Passed,
      list.append(setup_failures_rev, inherited_failures_rev),
    )
    AssertionFailed(failure) -> #(Failed, [
      failure,
      ..list.append(setup_failures_rev, inherited_failures_rev)
    ])
    AssertionSkipped -> #(
      Skipped,
      list.append(setup_failures_rev, inherited_failures_rev),
    )
  }
}
```

#### 3.0.0: a `case` with a branch for `AssertionPending` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/assertion_pending.gleam#L9-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn status_of(result: AssertionResult) -> Status {
  case result {
    AssertionOk -> Passed
    AssertionFailed(_) -> Failed
    AssertionSkipped -> Skipped
    AssertionPending -> Pending
  }
}
```

### Discovery errors

`discover.load` and `discover.to_suites` give a new error text for a test module that does not load. Code that compares the text must change:

- A `tests()` function that crashes gives `tests() crashed: <class>:<reason>`, for example `tests() crashed: error:...`. In 2.x the text was `call_tests_failed`.
- A `tests()` function whose value is not a test suite gives `tests() did not return a test suite: <value>`. In 2.x the run crashed.
- A pattern that cannot be searched gives `cannot search for test modules: <class>:<reason>`. In 2.x the text was `discover_test_modules_failed`.
- A pattern that matches no test module gives `<pattern>: no test module matches the pattern`, and the run fails. In 2.x the run had no tests from it and passed. Check each pattern, for example after you move a test folder.
- A test module whose beam file does not load gives `<module>: cannot load the module: <reason>`, and the run fails. In 2.x the module was skipped.

### Discovered suites with a context are now supported

Module discovery loads a test module whose `tests()` returns a suite with a context, for example from `unit_context.describe`. The suite runs with its own context. `discover.to_suite` puts each module suite in one group, and each suite keeps its own context. In 2.x, `discover.to_suite` gave the tests of such a suite `Nil` in place of their context.

## Step 5: Check the hook failures

3.0.0 has one rule for every hook failure:

- A failed setup hook gives `SetupFailed` to each test that it serves.
- A failed teardown hook does not change the status of a test. The other teardown hooks still run. The failure goes into the hook failures of the run report, and the run fails. With `runner.exit_on_failure`, the exit status is 1 (see [Exit status](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md#step-6-decide-the-exit-status)).

A setup hook and its teardown hook run only when at least one of the tests that they serve runs. In 2.x, the `before_all` and `after_all` hooks of a group with no test, and the suite hooks of a suite with no test, still ran. Do not use an empty group or suite only to run a hook: put the hook in a group that has tests. For a resource that all the tests of a tree share, use `context.setup` in `unit_context.describe`, or `steps.new_with_setup` for Gherkin. To run suites with different contexts together, use `suite.group` or `suite.join`.

### A setup whose process stops

A `before_all`, `before_each_suite` or `before_all_suites` hook, or a context setup (from `context.setup` or `steps.new_with_setup`), runs in a process that lives while its tests run. When that process stops, for example because a process linked to it crashed, the run report gets a `types.SetupStopped(setup, path, reason, not_run)`. `SetupStopped` is the second variant of `types.HookFailure`. A `case` on a `HookFailure` needs a branch for it.

- Each test that had not started is `SetupFailed`, with a failure such as `not run: the setup from before_all in "Database" stopped (killed)`. `not_run` lists the full names of these tests.
- The teardown hooks still run, in a new process.
- `types.failed` is `True`, and the summary line counts it as `setup stopped`.
- 2.x had no such result.

### A failed `after_all` hook

In 2.x, a failed `after_all`, `after_each_suite` or `after_all_suites` hook added a fake test to the results, with a name such as `<after_all>`. The test count grew by one, and the later hooks of the same kind did not run. In 3.0.0, every hook runs. `types.report_hook_failures(report)` has one `HookFailure` for each failure.

No file at the 2.1.3 tag looks for the fake test. The 2.1.3 runner code below makes it. At the first failed hook, it adds a `Failed` result with the name `<after_all>`, and it does not run the rest of the hooks.

#### 2.x: a failed `after_all` hook gives a fake `<after_all>` test <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/parallel.gleam#L1851-L1870"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
  case hooks {
    [] -> acc_rev
    [hook, ..rest] ->
      case run_hook_teardown(config, scope, context, hook) {
        Ok(_) -> run_after_all_chain(config, scope, context, rest, acc_rev)
        Error(message) -> {
          let result =
            TestResult(
              name: "<after_all>",
              full_name: list.append(scope, ["<after_all>"]),
              status: Failed,
              duration_ms: 0,
              tags: [],
              failures: [hook_failure("after_all", message)],
              kind: Unit,
            )
          [result, ..acc_rev]
        }
      }
  }
```

#### 3.0.0: read the hook failures of the report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/hook_failures.gleam#L10-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn stop_database() -> Result(Nil, String) {
  Error("the database did not stop")
}

fn database_suite() {
  describe("Database", [
    after_all(stop_database),
    it("reads a row", fn() { Ok(succeed()) }),
  ])
}

fn after_all_failed(report: RunReport) -> Bool {
  types.report_hook_failures(report)
  |> list.any(fn(failure) {
    case failure {
      TeardownFailed(hook: AfterAllHook, ..) -> True
      _ -> False
    }
  })
}
```

A failed `after_each` or `after_each_test` hook also keeps the status of its test. In 2.x, the test became `Failed`, also when it was `TimedOut`, `Skipped` or `SetupFailed`. In 3.0.0, the report has `TeardownFailed(hook: AfterEachHook, ..)` with the full test name in `path`.

### A failed setup hook, and a timeout

In 2.x, the tests of a failed `before_all`, `before_each_suite` or `before_all_suites` hook were `Failed`. In 3.0.0, they are `SetupFailed`. A test body that runs past its timeout is `TimedOut`, with the failure `timeout: test timed out`. In 2.x, a sequential run gave `Failed` for a timeout. Code that counts or matches statuses must handle `SetupFailed` and `TimedOut`.

No file at the 2.1.3 tag counts the broken tests. The 2.1.3 runner code below gives the status `Failed` to each test of a failed `before_all` hook, so code that counted `Failed` results counted these tests too.

#### 2.x: the tests of a failed `before_all` hook are `Failed` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/parallel.gleam#L610-L641"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn fail_test_nodes(
  scope: List(String),
  inherited_tags: List(String),
  nodes: List(Node(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case nodes {
    [] -> acc_rev
    [Test(name, tags, kind, _run, _timeout_ms, _source), ..rest] -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let failures = list.reverse(failures_rev)
      let result =
        TestResult(
          name: name,
          full_name: full_name,
          status: Failed,
          duration_ms: 0,
          tags: all_tags,
          failures: failures,
          kind: kind,
        )
      fail_test_nodes(scope, inherited_tags, rest, failures_rev, [
        result,
        ..acc_rev
      ])
    }
    [_other, ..rest] ->
      fail_test_nodes(scope, inherited_tags, rest, failures_rev, acc_rev)
  }
}
```

#### 3.0.0: count the broken tests by every failed status <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/hook_failures.gleam#L31-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn start_database() -> Result(Nil, String) {
  Error("the database did not start")
}

fn broken_database_suite() {
  describe("Broken database", [
    before_all(start_database),
    it("reads a row", fn() { Ok(succeed()) }),
    it("writes a row", fn() { Ok(succeed()) }),
  ])
}

fn count_broken(report: RunReport) -> Int {
  list.count(types.report_tests(report), fn(result) {
    case result.status {
      Failed | SetupFailed | TimedOut -> True
      Passed | Skipped | Pending -> False
    }
  })
}
```

### Hooks share a process with their scope

In 2.x, each hook and each test body ran in its own process. A process, a subject or an ETS table that a hook made stopped before the test body ran. In 3.0.0, a test runs its hooks and its body in one process. The `before_all` and `after_all` hooks of a group run in one setup process of that group. You do not have to change code for this. But a hook can now make a subject, and the test body can receive from it. The same code compiled in 2.x, but the test failed.

#### 3.0.0: a test receives a message that its hook sent <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/hook_process.gleam#L10-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Context {
  Context(inbox: Subject(String))
}

pub fn suite() {
  describe("Inbox", context.value(Context(inbox: process.new_subject())), [
    before_each(fn(_context) {
      let inbox = process.new_subject()
      process.send(inbox, "welcome")
      Ok(Context(inbox: inbox))
    }),
    it("gets the message that its hook sent", fn(context: Context) {
      process.receive(context.inbox, 100)
      |> should
      |> be_equal(Ok("welcome"))
      |> or_fail_with("expected the message from the before_each hook")
    }),
  ])
}
```

A test process that stops during the body gives `Failed` with `crash: worker crashed in <group>: <reason>`. In 2.x, the failure was `crash: killed`.

When a test ends, its process exits with reason `shutdown`. A process that the test started and linked to itself, such as an actor from `process.start_actor`, stops with it, also when the test passed. In 2.x, such a process stayed alive after a test that passed, failed or crashed. Do not keep a linked process from one test for a later test: start it in a `before_all` hook. A process that a `before_all` hook or a context setup starts and links stops after the last test that the hook serves: its setup process exits with reason `shutdown`.

## Step 6: Update the reporters

### Reporter functions take a `RunReport`

These functions take a `types.RunReport` in place of `List(TestResult)`: `bdd.render`, `bdd.format`, `bdd.report`, `bdd.format_summary_only`, `json.render`, `json.format`, `json.format_pretty`, `json.report`, `json.report_pretty`, `gherkin.format` and `gherkin.report`. The `report` functions return the report. To format a list of results that you made, use `types.run_report(tests: results, hook_failures: [], reporter_crashes: [])`.

#### 2.x: format a list of results <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/reporters/bdd_formatting.gleam#L1-L31"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "passes",
      full_name: ["Example Suite", "passes"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let report = bdd.format(sample_results())

      report
      |> should
      |> match_snapshot("./test/snapshots/bdd_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
```

#### 3.0.0: format a run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/bdd_formatting.gleam#L1-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "passes",
      groups: ["Example Suite"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let report =
        bdd.format(
          types.run_report(
            tests: sample_results(),
            hook_failures: [],
            reporter_crashes: [],
          ),
        )

      report
      |> should
      |> match_snapshot("./test/snapshots/bdd_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
```

### A Gherkin result kind has the Feature and the Rule

`types.GherkinScenario` has three labelled fields: `GherkinScenario(scenario_id:, feature:, rule:)`. `feature` is the name of the Feature, for example `Some("Cart")`, for a scenario in the group of its Feature, and `None` for a scenario of `steps.Scenarios`, which is in no Feature group. `rule` is the name of the Rule group, for example `Some("Rule: Stock")`, for a scenario inside a Rule, and `None` for a scenario outside a Rule. Code that builds a result gives both. A pattern that matches the kind uses `GherkinScenario(..)` or names the fields.

The BDD and Gherkin reporters read the Feature and the Rule from the kind, not from the place of a group or from a group name that starts with `Rule:`. In 2.x, both reporters printed `Feature:` on the first group, so a suite name above the Feature was printed as the Feature. In 3.0.0 both reporters print `Feature: <feature>` on the group of the Feature. For a scenario with `feature: None`, the Gherkin reporter prints its groups, joined with ` > `, as the heading.

The Gherkin reporter also heads other results by their groups:

| Result | 2.x heading | 3.0.0 heading |
|---|---|---|
| A unit test `sums` in the groups `math` and `add`, given to `gherkin.format` | `Feature: math` | `math > add` |
| A result with no groups and no Feature, for example a result built by hand | `Feature: <test name>` | no heading line: the scenario line prints alone, for example `Scenario: alone ✓` |

#### 2.x: a Gherkin result with only the id <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/reporters/gherkin_formatting.gleam#L6-L18"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "Scenario A",
      full_name: ["Example Feature", "Scenario A"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.GherkinScenario("example"),
    ),
  ]
}
```

#### 3.0.0: a Gherkin result with the id, the Feature and the Rule <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/gherkin_formatting.gleam#L7-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "Scenario A",
      groups: ["Example Feature"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.GherkinScenario(
        scenario_id: "example",
        feature: Some("Example Feature"),
        rule: None,
      ),
    ),
  ]
}
```

### The summary line

The summary line of the BDD and Gherkin reporters lists the extra counts in a new order: skipped, pending, timed out, setup failed. In 2.x, the order was setup failed, timed out, pending, skipped. The extra counts come after `N passed` and before ` in <duration>`, and each shows only when it is not 0. Two counts are new, after setup failed: `N teardown failed` and `N setup stopped`. For example: `Summary: 4 run, 1 failed, 2 passed, 1 skipped, 1 teardown failed in 12ms`. Update a test or a tool that compares the exact summary text.

### Progress events

The progress event API is removed: `reporters/types.ReporterEvent`, `HookKind`, `HookOutcome` and `progress.handle_event`. Use `progress.line(reporter, event)` with a `progress.ProgressEvent`: `RunStartedProgress`, `TestFinishedProgress` or `RunFinishedProgress`. `progress.line` returns the text, not an `Option`. `progress.render` also takes a `progress.ProgressEvent`.

#### 2.x: `progress.handle_event` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/reporters/progress_handle_event.gleam#L1-L38"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/file
import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/result

fn write_progress_line_to_file(text: String) {
  file.write("test/tmp/progress_handle_event.txt", text)
  |> result.unwrap(Nil)
}

pub fn tests() {
  describe("Progress reporter: handle_event", [
    it("writes an in-place line (including carriage return)", fn() {
      let reporter = progress.new()
      let maybe_progress_text =
        progress.handle_event(reporter, reporter_types.RunStarted(total: 10))
      case maybe_progress_text {
        Some(text) -> write_progress_line_to_file(text)
        None -> Nil
      }

      use text <- result.try(
        file.read("test/tmp/progress_handle_event.txt")
        |> result.map_error(file.error_to_string),
      )

      text
      |> should
      |> match_regex("\\r0/10 \\[[^\\]]+\\] 0%")
      |> or_fail_with(
        "expected progress output to include carriage-returned 0/10 0% line",
      )
    }),
  ])
}
```

#### 3.0.0: `progress.line` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/progress_line.gleam#L1-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file
import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/unit.{describe, it}
import gleam/result

fn write_progress_line_to_file(text: String) {
  file.write("test/tmp/progress_line.txt", text)
  |> result.unwrap(Nil)
}

pub fn tests() {
  describe("Progress reporter: line", [
    it("writes an in-place line (including carriage return)", fn() {
      let reporter = progress.new()
      progress.line(reporter, progress.RunStartedProgress(total: 10))
      |> write_progress_line_to_file

      use text <- result.try(
        file.read("test/tmp/progress_line.txt")
        |> result.map_error(file.error_to_string),
      )

      text
      |> should
      |> match_regex("\\r0/10 \\[[^\\]]+\\] 0%")
      |> or_fail_with(
        "expected progress output to include carriage-returned 0/10 0% line",
      )
    }),
  ])
}
```

### Custom reports

In 2.x, `runner.results_reporters` took only the built-in reporters. A custom report or a Gherkin report had to print after `runner.run()`, and `runner.exit_on_failure()` ended the program before it printed. In 3.0.0, give your formatter to the runner as `reporter_types.Custom(render)`, with `render` a `fn(RunReport) -> String`. The report prints at the end of the run, and `runner.exit_on_failure()` then gives exit status 1 when the run fails. The runner calls `render` in the process of the run, so `render` must return. See [Custom post-run reporter](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md#step-4-write-a-reporter-of-your-own).

### `ResultsReporter` has the variant `Custom`

`reporters/types.ResultsReporter` has a new variant: `Custom(render:)`. In 2.x it had only `Bdd` and `Json`. A `case` on a `ResultsReporter` needs a branch for `Custom`, or the code does not compile. Code that only builds reporters with `bdd.new()` and `json.new()` needs no change.

#### 2.x: a `case` on `ResultsReporter` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/runner.gleam#L1494-L1502"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn render_results_reporter(
  reporter: reporter_types.ResultsReporter,
  results: List(TestResult),
) -> String {
  case reporter {
    reporter_types.Bdd(config) -> bdd.render(config, results)
    reporter_types.Json(config) -> json.render(config, results)
  }
}
```

#### 3.0.0: a `case` with a branch for `Custom` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/results_reporter_case.gleam#L7-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn reporter_name(reporter: reporter_types.ResultsReporter) -> String {
  case reporter {
    reporter_types.Bdd(_) -> "bdd"
    reporter_types.Json(_) -> "json"
    reporter_types.Custom(render: _) -> "custom"
  }
}
```

### `FailurePayload` has the variant `StepFailure`

`types.FailurePayload` has a new variant: `StepFailure(keyword:, text:, file:, line:, cause:)`. A failure in a Gherkin step has it as its payload: it names the step, its `.feature` file and its line, and holds the payload of the failure inside the step as `cause`. A `case` on a `FailurePayload` needs a branch for it, or the code does not compile. Code that reads the payload of a failed scenario, for example the `EqualityFailure` of a failed check, reads it from `cause`.

#### 2.x: a `case` on `FailurePayload` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/reporters/json.gleam#L317-L364"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn build_payload_fields(
  payload: Option(FailurePayload),
) -> List(#(String, Json)) {
  case payload {
    None -> []
    Some(EqualityFailure(actual, expected)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
    ]
    Some(BooleanFailure(actual, expected)) -> [
      #("expected", json.bool(expected)),
      #("actual", json.bool(actual)),
    ]
    Some(OptionFailure(actual, expected_some)) -> [
      #("expected_some", json.bool(expected_some)),
      #("actual", json.string(actual)),
    ]
    Some(ResultFailure(actual, expected_ok)) -> [
      #("expected_ok", json.bool(expected_ok)),
      #("actual", json.string(actual)),
    ]
    Some(CollectionFailure(actual, expected, operation)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("operation", json.string(operation)),
    ]
    Some(ComparisonFailure(actual, expected, operator)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("comparison_operator", json.string(operator)),
    ]
    Some(StringMatchFailure(actual, pattern, operation)) -> [
      #("pattern", json.string(pattern)),
      #("actual", json.string(actual)),
      #("operation", json.string(operation)),
    ]
    Some(SnapshotFailure(actual, expected, snapshot_path, is_missing)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("snapshot_path", json.string(snapshot_path)),
      #("is_missing", json.bool(is_missing)),
    ]
    Some(CustomMatcherFailure(actual, description)) -> [
      #("actual", json.string(actual)),
      #("description", json.string(description)),
    ]
  }
}
```

#### 3.0.0: a `case` with a branch for `StepFailure` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/failure_payload_case.gleam#L8-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn expected_value(payload: Option(FailurePayload)) -> Option(String) {
  case payload {
    Some(EqualityFailure(expected:, ..)) -> Some(expected)
    Some(StepFailure(cause:, ..)) -> expected_value(cause)
    _ -> None
  }
}
```

## Step 7: Update the tools that read the JSON report

The JSON report has schema version `2.0`. The Gleam call changes only because `json.format` takes the run report. A tool that reads the JSON must accept the new version and the new fields:

- `summary` has the counts `teardown_failed` (teardown hooks that failed) and `setup_stopped` (setups whose process stopped).
- The object has the list `hook_failures`. In JSON schema version 1.0, a failed `after_all` hook was a test named `<after_all>` in `tests`.
- A failed teardown hook is an object with `"kind": "teardown_failed"`, `hook`, `path` and `message`.
- A setup that stopped is an object with `"kind": "setup_stopped"`, `hook`, `path`, `message` and `not_run`, the full names of the tests that did not run.
- A Gherkin test object has `feature` and `rule` after `kind`. `feature` is the name of the Feature, or `null` for a scenario of `steps.Scenarios`. `rule` is the name of its Rule group, for example `"Rule: Stock"`, or `null` for a scenario outside a Rule. Other tests do not have `feature` or `rule`.
- The `system` object has `gleam_stdlib_version` in place of `gleam_version`. The value is the same: the version of the `gleam_stdlib` package, not the version of the Gleam compiler.
- The text ends with a newline, also in compact form. A tool that compares the whole text must expect it.
- A failure in a Gherkin step has a `step` object with `keyword`, `text`, `file` and `line`, before the fields of the failure inside the step, such as `expected` and `actual`. `file` and `line` are `null` when they are not known.

#### 2.x: JSON from a list of results <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/reporters/json_api_format.gleam#L6-L15"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let results = runner.new([example_suite()]) |> runner.run()
  json.format(results)
}
```

#### 3.0.0: JSON from a run report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/json_format.gleam#L7-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let report = runner.new([example_suite()]) |> runner.run()
  json.format(report)
}
```

## Step 8: Update parser code and feature files

### Code that builds the syntax tree

This change affects only code that builds or reads `gherkin/types` values directly. Step definitions do not change. They still read `context.table` and `context.doc_string`.

- `Step` holds `doc_string` and `data_table` in place of `argument`, and the new field `line`: the line of the step that the parser read, or `None` for an inline step. The `StepArgument` type is removed.
- `Scenario` is one record with `keyword`, `description` and `examples`. The `ScenarioOutline` variant is removed: an outline is a `Scenario` with `Examples`. A `case` on `Scenario` has one branch.
- `Background` holds `name` and `description`.
- `Feature` has a new field, `rules`.
- `StepKeyword` has a new variant, `Asterisk`. A `case` on `StepKeyword` needs a branch for it.
- `resolve_keyword` is removed. Use `resolve_phase`.

#### 2.x: `resolve_keyword` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_types.gleam#L24-L29"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("resolve_keyword turns And/But into the previous keyword", fn() {
      resolve_keyword(And, Given)
      |> should
      |> be_equal(Given)
      |> or_fail_with("expected And after Given to resolve to Given")
    }),
```

#### 3.0.0: `resolve_phase` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L13-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("resolve_phase turns And into the phase of the step before it", fn() {
      resolve_phase(keyword: And, previous: Some(GivenPhase))
      |> should
      |> be_equal(Ok(GivenPhase))
      |> or_fail_with("expected And after Given to resolve to GivenPhase")
    }),
```

#### 2.x: a `Step` with `argument` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_types.gleam#L30-L35"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("Step can be constructed", fn() {
      Step(keyword: Given, text: "I have 1 item", argument: None)
      |> should
      |> be_equal(Step(keyword: Given, text: "I have 1 item", argument: None))
      |> or_fail_with("expected Step to be constructible")
    }),
```

#### 3.0.0: a `Step` with `doc_string`, `data_table` and `line` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L19-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("Step can be constructed", fn() {
      Step(
        keyword: Given,
        text: "I have 1 item",
        doc_string: None,
        data_table: None,
        line: None,
      )
      |> should
      |> be_equal(Step(
        keyword: Given,
        text: "I have 1 item",
        doc_string: None,
        data_table: None,
        line: None,
      ))
      |> or_fail_with("expected Step to be constructible")
    }),
```

#### 2.x: a `Feature` with no `rules` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_types.gleam#L79-L103"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("Feature can be constructed", fn() {
      let step = Step(keyword: Given, text: "I have 1 item", argument: None)
      let scenario = Scenario(name: "Example scenario", tags: [], steps: [step])

      Feature(
        name: "Example feature",
        source: None,
        description: None,
        tags: [],
        background: None,
        scenarios: [scenario],
      )
      |> should
      |> be_equal(
        Feature(
          name: "Example feature",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [scenario],
        ),
      )
      |> or_fail_with("expected Feature to be constructible")
    }),
```

#### 3.0.0: a `Feature` with `rules` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L37-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("Feature can be constructed", fn() {
      let step =
        Step(
          keyword: Given,
          text: "I have 1 item",
          doc_string: None,
          data_table: None,
          line: None,
        )
      let scenario =
        Scenario(
          keyword: types.KeywordScenario,
          name: "Example scenario",
          description: None,
          tags: [],
          steps: [step],
          examples: [],
        )

      Feature(
        name: "Example feature",
        source: None,
        description: None,
        tags: [],
        background: None,
        scenarios: [scenario],
        rules: [],
      )
      |> should
      |> be_equal(
        Feature(
          name: "Example feature",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [scenario],
          rules: [],
        ),
      )
      |> or_fail_with("expected Feature to be constructible")
    }),
```

#### 2.x: a `ScenarioOutline` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/gherkin_types.gleam#L104-L122"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("ScenarioOutline can be constructed", fn() {
      let step =
        Step(keyword: Given, text: "I have <count> items", argument: None)

      ScenarioOutline(
        name: "Example outline",
        tags: [],
        steps: [step],
        examples: ExamplesTable(headers: ["count"], rows: [["1"], ["5"]]),
      )
      |> should
      |> be_equal(ScenarioOutline(
        name: "Example outline",
        tags: [],
        steps: [step],
        examples: ExamplesTable(headers: ["count"], rows: [["1"], ["5"]]),
      ))
      |> or_fail_with("expected ScenarioOutline to be constructible")
    }),
```

#### 3.0.0: a `Scenario` with `Examples` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L79-L116"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("a Scenario Outline is a Scenario with Examples", fn() {
      let step =
        Step(
          keyword: Given,
          text: "I have <count> items",
          doc_string: None,
          data_table: None,
          line: None,
        )
      let examples =
        Examples(
          name: "",
          description: None,
          tags: [],
          table: Some(ExamplesTable(headers: ["count"], rows: [["1"], ["5"]])),
        )

      Scenario(
        keyword: KeywordScenarioOutline,
        name: "Example outline",
        description: None,
        tags: [],
        steps: [step],
        examples: [examples],
      )
      |> should
      |> be_equal(
        Scenario(
          keyword: KeywordScenarioOutline,
          name: "Example outline",
          description: None,
          tags: [],
          steps: [step],
          examples: [examples],
        ),
      )
      |> or_fail_with("expected a Scenario with Examples to be constructible")
    }),
```

### Parse errors are typed

`parser.parse_string` returns `Result(Feature, ParseError)`. `parser.parse_file` returns `Result(Feature, FeatureFileError)`. `discover.LoadResult.errors` is a `List(parser.FeatureFileError)`. In 2.x, each error was a `String`. Use `parser.parse_error_to_string` or `parser.feature_file_error_to_string` to get the text. A `parse_error_to_string` message starts with `line N:`. A `feature_file_error_to_string` message starts with the path for a parse error, for example `test/cart.feature: line 3: ...`. For the other errors it starts with `Failed to read feature file:`, `No feature files match the pattern` or `Cannot search for feature files with the pattern`.

#### 2.x: a parse error is a `String` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/gherkin/parser.gleam#L8-L22"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
    it("parse_string parses a minimal feature", fn() {
      let content =
        "@smoke\n"
        <> "Feature: Demo\n"
        <> "\n"
        <> "  Scenario: One\n"
        <> "    Given a thing\n"

      use feature <- result.try(parser.parse_string(content))

      feature.name
      |> should
      |> be_equal("Demo")
      |> or_fail_with("expected feature name Demo")
    }),
```

#### 3.0.0: turn a `ParseError` into text <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L117-L134"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("parse_string parses a minimal feature", fn() {
      let content =
        "@smoke\n"
        <> "Feature: Demo\n"
        <> "\n"
        <> "  Scenario: One\n"
        <> "    Given a thing\n"

      use feature <- result.try(
        parser.parse_string(content)
        |> result.map_error(parser.parse_error_to_string),
      )

      feature.name
      |> should
      |> be_equal("Demo")
      |> or_fail_with("expected feature name Demo")
    }),
```

#### 3.0.0: the text of a parse error <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/gherkin_syntax_tree.gleam#L135-L144"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("a parse error names its line", fn() {
      parser.parse_string("Feature: Demo\n  Scenario: One\n    And a thing\n")
      |> result.map(fn(feature) { feature.name })
      |> result.map_error(parser.parse_error_to_string)
      |> should
      |> be_equal(Error(
        "line 3: \"And a thing\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
      ))
      |> or_fail_with("expected a parse error on line 3")
    }),
```

### `.feature` files

The parser follows the official Gherkin grammar. A `.feature` file that 2.x read can be an error in 3.0.0. Run your tests, then fix each file that the error names.

| 2.x | 3.0.0 | What to do |
|---|---|---|
| Text after the steps of a scenario, a Background after a scenario, or a step after an `Examples` table was ignored. | An `UnexpectedLine` error that names the line. | Move or remove the line. |
| `And`, `But` or `*` as the first step of a Background ran as a Given step. | A parse error, for example `line 3: "And a" has no step before it. ...`. In an inline feature, each scenario fails. | Change the first step to `Given`, `When` or `Then`. |
| `DocString is not closed` | `line 7: The DocString that starts on line 7 is not closed`. Every message starts with `line N:`. | Update tests that compare parse error text. |
| Each `Examples` row test was named `Adding items`. | `Adding items (Example 1)`, or `Adding items (Bulk, Example 1)` for an `Examples: Bulk` section. | Update name filters and tests that compare result names. |
| A `Scenario Outline` with no `Examples` made no tests. | It makes one test. | Add an `Examples` table, or remove the outline. |
| `@a b` gave the tag `a`. `@a@b` gave one tag. | `@a b` is a `TagContainsWhitespace` error. `@a@b` gives `a` and `b`. `@tag #comment` ignores the comment. | Remove the space. |
| `# language: fr` was a comment. | An `UnsupportedLanguage` error. Only `en` is supported. | Remove the line, or use `# language: en`. |
| A description lost its leading whitespace and empty lines. | A description keeps them. | Update tests that compare descriptions. |
| A DocString line kept an escaped separator, such as `\"\"\"`, as written. | Each escaped separator of the active separator becomes the separator: `\"\"\"` becomes `"""` and `` \`\`\` `` becomes ```` ``` ````. | Update steps that expect the backslashes. |

## Step 9: Update sandbox calls

`sandbox.run_isolated` takes the function and its input as two arguments: `run_isolated(config, run, input)`. A function with no data takes `Nil`.

#### 2.x: `run_isolated` with a closure <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/sandboxing.gleam#L1-L51"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn loop_forever() {
  loop_forever()
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, fn() { 123 })

      result
      |> should
      |> be_equal(SandboxCompleted(123))
      |> or_fail_with("expected SandboxCompleted(123)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, fn() { panic as "boom" })

      let did_crash = case result {
        SandboxCrashed(_) -> True
        _ -> False
      }

      did_crash
      |> should
      |> be_equal(True)
      |> or_fail_with("expected SandboxCrashed(...)")
    }),
  ])
}
```

#### 3.0.0: `run_isolated` with a function and its input <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/upgrading/sandbox.gleam#L1-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn double(number: Int) -> Int {
  number * 2
}

fn loop_forever(_input: Nil) -> Nil {
  loop_forever(Nil)
}

fn crash(message: String) -> Int {
  panic as message
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 60_000, show_crash_reports: False)
      let result = sandbox.run_isolated(config, double, 61)

      result
      |> should
      |> be_equal(SandboxCompleted(122))
      |> or_fail_with("expected SandboxCompleted(122)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever, Nil)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 60_000, show_crash_reports: False)
      let result = sandbox.run_isolated(config, crash, "boom")

      let did_crash = case result {
        SandboxCrashed(_) -> True
        _ -> False
      }

      did_crash
      |> should
      |> be_equal(True)
      |> or_fail_with("expected SandboxCrashed(...)")
    }),
  ])
}
```

## Step 10: Check the polling helpers

`process.await_ready` and `process.await_some` measure `timeout_ms` on the monotonic clock. The time that the check takes counts, and `interval_ms: 0` still times out. In 2.x, each loop took `interval_ms` off the timeout, so `interval_ms: 0` waited forever and a slow check waited longer than `timeout_ms`. You do not have to change code, but a slow check can now time out sooner.

## Step 11: Replace the removed items

### Three items that did nothing

`types.TestKind.Integration`, the alias `types.TestSuiteItem` and the old module `dream_test/context` (`TestContext`, `new`, `failures`, `add_failure`) are removed. No part of Dream Test made or read them. The name `dream_test/context` now holds the context of `unit_context.describe`.

No test ever had the kind `Integration`. To mark integration tests, give them a tag, and filter on the tag:

#### 2.x: the `Integration` kind, never given to a test <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/src/dream_test/types.gleam#L118-L130"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
/// The kind/category of a test.
///
/// Used to distinguish between different testing styles:
///
/// - `Unit` - Standard unit tests from `describe`/`it`
/// - `Integration` - Integration tests (for future use)
/// - `GherkinScenario(id)` - Tests from Gherkin features (inline DSL or `.feature` files)
///
pub type TestKind {
  Unit
  Integration
  GherkinScenario(String)
}
```

#### 3.0.0: tag the integration tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/tagging.gleam#L7-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() {
  describe("Tagged tests", [
    // Tag a whole group (all tests inside inherit these tags)
    group("integration", [
      it("slow path", fn() { Ok(succeed()) }),
      it("another slow path", fn() { Ok(succeed()) }),
    ])
      |> with_tags(["integration", "slow"]),

    // Or tag a single test
    it("smoke", fn() { Ok(succeed()) })
      |> with_tags(["smoke"]),
  ])
}
```

#### 3.0.0: run only the tests with a tag <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/filter_tests.gleam#L22-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn main() {
  runner.new([tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

`types.TestSuiteItem(context)` was another name for `types.Node(context)`. Use `types.Node(context)`.

`dream_test/context` held a list of failures (`TestContext`, `new`, `failures`, `add_failure`) that the runner never used. Keep such a list in your own code if you need it.

#### 2.x: `dream_test/context` <a href="https://github.com/TrustBound/dream_test/blob/2.1.3/examples/snippets/test/snippets/utils/context_helpers.gleam#L1-L32"><img align="right" alt="Code at 2.1.3" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.1.3-lightgrey.svg?style=flat-square"></a>

```gleam
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionFailure}
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/context", [
    it("new has no failures", fn() {
      context.new()
      |> context.failures()
      |> should
      |> be_equal([])
      |> or_fail_with("expected new context to have no failures")
    }),

    it("add_failure stores failures newest-first", fn() {
      let first_failure =
        AssertionFailure(operator: "op1", message: "m1", payload: None)
      let second_failure =
        AssertionFailure(operator: "op2", message: "m2", payload: None)

      context.new()
      |> context.add_failure(first_failure)
      |> context.add_failure(second_failure)
      |> context.failures()
      |> should
      |> be_equal([second_failure, first_failure])
      |> or_fail_with("expected newest-first failure ordering")
    }),
  ])
}
```

| Removed in 3.0.0 | Use in its place |
|---|---|
| `dream_test/gherkin/world` (`put`, `get`, `get_or`, `has`, `delete`, `scenario_id`, `new_world`, `cleanup`) | The scenario state. See [Gherkin step definitions](#step-3-port-the-gherkin-step-definitions). |
| `gherkin/steps.step` | `steps.given`, `steps.when` or `steps.then` |
| `gherkin/steps.when_`, `gherkin/steps.then_` | `steps.when`, `steps.then` |
| `gherkin/steps.StepHandler` | `steps.StepDefinition(state)` |
| `gherkin/types.resolve_keyword` | `gherkin/types.resolve_phase` |
| `gherkin/types.StepArgument` | The `doc_string` and `data_table` fields of `Step` |
| `gherkin/types.ScenarioOutline` | `Scenario` with `examples` |
| `runner.has_failures` | `types.failed` |
| `reporters/types.ReporterEvent`, `HookKind`, `HookOutcome`, `progress.handle_event` | `progress.ProgressEvent` and `progress.line` |
| `types.TestKind.Integration` | A tag, for example `unit.with_tags(["integration"])`, and `runner.filter_tests` |
| `types.TestSuiteItem` | `types.Node` |
| `dream_test/context` (`TestContext`, `new`, `failures`, `add_failure`) | Nothing. The runner never used it. |
| `types.ModuleCoverage`, `types.CoverageSummary` | `dream_test/coverage`. Nothing in 2.x filled these types. See the Coverage section of the [main README](https://github.com/TrustBound/dream_test/blob/main/README.md#coverage). |

## Test your code

After the upgrade, a test can change its name without failing: an Examples row of a Gherkin scenario is now its own test, named `Adding items (Example 1)` or `Adding items (Bulk, Example 1)`. A filter, a CI dashboard or a tool that matched the old names silently stops matching. Pin the names that matter with a test. This one parses a feature with Rules and two Examples sections, runs it, and checks the full name of each test:

### Check the test names of a feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_rule_names.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/string

fn full_name(result: TestResult) -> String {
  string.join(types.full_name(result.groups, result.name), " > ")
}

pub fn tests() {
  describe("Gherkin Rules and Examples", [
    it("names each test after its Rule and its Examples section", fn() {
      let assert Ok(feature) = parser.parse_file("test/features/stock.feature")
      let suite =
        steps.feature_suite(registry: steps.new(initial: Nil), feature: feature)

      runner.new([suite])
      |> runner.run()
      |> types.report_tests
      |> list.map(full_name)
      |> should
      |> be_equal([
        "Stock control > Rule: An item can be sold only when it is in stock > Sell from stock",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Small orders, Example 1)",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Small orders, Example 2)",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Large orders, Example 3)",
        "Stock control > Rule: A sold-out shop sells nothing > Nothing to sell",
      ])
      |> or_fail_with("expected the Rule group and the Examples name")
    }),
  ])
}
```

### The report of the name check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_upgrading_names.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Gherkin Rules and Examples
  ✓ names each test after its Rule and its Examples section

Summary: 1 run, 0 failed, 1 passed in 0ms
```

Do the same for the counts that matter to you. `summary.count(report)` from `dream_test/reporters/summary` gives every count of the summary line, so a test can check that the upgraded suite runs as many tests as it did on 2.x.

## Common pitfalls

**A count of failed tests that misses some.** *Symptom:* a tool reports fewer broken tests than the summary. *Fix:* 3.0.0 has `SetupFailed` and `TimedOut` statuses that 2.x reported as `Failed`. Count every status for which `types.is_failure` is `True`.

**A green run with a failed cleanup.** *Symptom:* every test passes, and CI is red. *Fix:* a failed teardown hook now fails the run, and is in `types.report_hook_failures(report)`. Fix the hook, or read the `Setup and teardown failures:` section of the report.

**Name filters that match nothing.** *Symptom:* a filtered run fails with `0 run` and `No tests ran`. *Fix:* test names of Gherkin examples changed, and `full_name` is now `groups` plus `name`. Use `types.full_name(info.groups, info.name)`, and test your filters.

**A discovery pattern that used to pass silently.** *Symptom:* `no test module matches the pattern` after the upgrade. *Fix:* 2.x passed when a pattern found nothing. 3.0.0 fails, on purpose. Fix the pattern.

**Feature files that 2.x read.** *Symptom:* a parse error that names a line which 2.x ignored. *Fix:* the parser follows the official grammar now. Fix the line, as the table in [Step 8](#step-8-update-parser-code-and-feature-files) shows.

## Where to go next

- [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md): the 3.0.0 way to write steps, with a typed state.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md#step-6-decide-the-exit-status): every case that gives exit status 1.
- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): how hooks fail and which process runs them.
- [The changelog](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md): the full list of changes.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/): every module of 3.0.0.
