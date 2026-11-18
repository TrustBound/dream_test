## Gherkin / BDD testing

### What is Gherkin?

**Gherkin** is a lightweight, plain-text format for writing **behavior-driven development (BDD)** specs. It’s commonly associated with tools like Cucumber, and it’s designed to be readable by both engineers and non-engineers.

At a high level, you describe behavior using a small vocabulary:

- **Feature**: a capability you’re describing (a suite of scenarios)
- **Scenario**: one concrete example (a test)
- **Background**: steps that should run before every scenario (shared setup)
- **Given / When / Then**: a convention for structuring steps:
  - **Given**: starting state / setup
  - **When**: the action
  - **Then**: the expected outcome

In Dream Test, you write Gherkin either as standard `.feature` files or directly in Gleam, and you implement behavior by mapping step text to step functions (a “step registry”).

Unit tests are great for “input → output.” Gherkin is for “a sequence of behavior over time.”

This chapter explains Dream Test’s Gherkin layer as an engineering tool:

- It’s for scenarios where each step changes or checks one scenario state
- It’s for readable specs you can share with product/QA
- It’s for reusing step definitions across many scenarios

### Mental model

- A **scenario** is a test.
- Each feature has one **state type** that you choose, for example `Int` or a `Cart` record. The step registry gets its initial value: `steps.new(initial: 0)`.
- Each scenario starts from the initial value in its own process. The state is an immutable value, so scenarios cannot share it.
- A **step registry** maps text patterns to step definitions:
  - an `Action` gets the state and returns the new state, or an error
  - a `Check` gets the state and returns an assertion result. It cannot change the state.

Dream Test includes a Gherkin DSL that lets you write scenarios with **Given/When/Then** structure.

### When to use Gherkin

- You want tests that are readable by non-engineers (product, QA, support).
- You want to model behavior as scenarios where each step changes or checks a state.
- You want to reuse step definitions across many scenarios.

If your tests are mostly “function input → output”, the unit DSL (`describe` / `it`) is usually simpler.

### The core pieces

- **Feature**: a suite of scenarios
- **Scenario**: a list of steps (Given/When/Then/And/But/`*`)
- **Step registry**: maps step patterns to definitions, one phase (Given, When or Then) for each definition, and holds the initial state
- **State**: the value that each step gets from the step before it
- **Captures**: placeholder values parsed from step text

### Step definitions and `StepContext`

Each step function gets two arguments: the scenario state and a `StepContext` record.

- `Action(run)`: `run(state, context)` returns `Ok(new_state)`, or `Error(message)` to fail the scenario.
- `Check(run)`: `run(state, context)` returns an assertion result, like a unit test body. The next step gets the same state.

The `StepContext` fields:

- `context.captures`: the placeholder captures extracted from the step text
- `context.table`: the DataTable of the step, if any
- `context.doc_string`: the DocString of the step, if any
- `context.scenario_id`: the id of the scenario, for example `"Shopping Cart::Adding items"`

When a step fails, the steps after it do not run.

Important Gleam detail: when you access record fields like `context.captures`, Gleam needs to know the record type.
That’s why the examples annotate `context: StepContext` (it’s the minimal type hint needed for record field access).

The capture helpers (`get_int`, `get_float`, `get_string`, `get_word`) return a `Result`. Pass the error on with `use value <- result.try(get_int(context.captures, 0))`. Then a wrong capture fails the scenario with a message such as `Capture 0 is the word "apples", not an integer`. Do not use `result.unwrap`: the scenario then runs with a wrong value.

### Inline Gherkin (the “hero” example)

#### An inline feature <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_hero.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{but, feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
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
    |> steps.given("I have {int} items in my cart", Action(step_have_items))
    |> steps.when_("I add {int} more items", Action(step_add_items))
    |> steps.then_("I should have {int} items total", Check(step_should_have))

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

What to notice in this example:

- The step registry is built once and shared by scenarios.
- The state is an `Int`. Each scenario starts from `0`, so scenarios don’t leak into each other.
- `context.captures` turns step text into typed values (via helpers like `get_int`).

### Placeholders (`{int}`, `{float}`, `{string}`, `{word}`)

Placeholders let you capture values from the step text into `context.captures`.
Typed helpers like `get_int` parse the capture into the right type.

#### Typed placeholders <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_placeholders.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, Action, Check, get_float, get_int, get_string, get_word,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

pub type Values {
  Values(int: Int, float: Float, string: String, word: String)
}

// {int} captures integers
fn step_int(values: Values, context: StepContext) {
  use value <- result.try(get_int(context.captures, 0))
  Ok(Values(..values, int: value))
}

// {float} captures decimals (works with $ prefix too)
fn step_float(values: Values, context: StepContext) {
  use value <- result.try(get_float(context.captures, 0))
  Ok(Values(..values, float: value))
}

// {string} captures quoted strings
fn step_string(values: Values, context: StepContext) {
  use value <- result.try(get_string(context.captures, 0))
  Ok(Values(..values, string: value))
}

// {word} captures a single unquoted word
fn step_word(values: Values, context: StepContext) {
  use value <- result.try(get_word(context.captures, 0))
  Ok(Values(..values, word: value))
}

fn step_everything_works(values: Values, _context: StepContext) {
  values
  |> should
  |> be_equal(Values(
    int: 42,
    float: 19.99,
    string: "hello world",
    word: "alice",
  ))
  |> or_fail_with("every placeholder should give its value")
}

pub fn tests() {
  let steps =
    steps.new(initial: Values(int: 0, float: 0.0, string: "", word: ""))
    |> steps.given("I have {int} items", Action(step_int))
    |> steps.given("the price is ${float}", Action(step_float))
    |> steps.given("the message is {string}", Action(step_string))
    |> steps.given("the user is {word}", Action(step_word))
    |> steps.then_("everything works", Check(step_everything_works))

  feature("Placeholder Types", steps, [
    scenario("Using different placeholders", [
      given("I have 42 items"),
      given("the price is $19.99"),
      given("the message is \"hello world\""),
      given("the user is alice"),
      then("everything works"),
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

### Phases: Given, When, Then, And, But and `*`

Given, When and Then are the three phases of a scenario: Arrange, Act and Assert.
Each step definition belongs to one phase. Register it with `steps.given`, `steps.when_` or `steps.then_`.
A step matches only the step definitions of its phase, so a `Given` definition never runs for a `When` step.

`And`, `But` and `*` take the phase of the step before them.
Use `*` (the `asterisk` helper in the inline DSL) for a list of steps where Given, When or Then reads badly.

Rules for the first step:

- The first step of a Background must use Given, When or Then.
- The first step of a Scenario or Scenario Outline must use Given, When or Then, unless a Background step runs before it.
- When a Background step runs before it, a Scenario can start with `And`, `But` or `*`. That step takes the phase of the last Background step.
- In a Rule, the Feature Background steps and the Rule Background steps both run before the scenario.
- The Background steps get the initial state first. The scenario steps then get the state that the last Background step gave.

A `.feature` file that breaks these rules does not parse. The error names the file and the line.
An inline feature that breaks these rules fails each scenario with the same message, before any step runs.

Each pattern can have one step definition in each phase.
A second definition of the same pattern in the same phase is a duplicate.
`steps.validate` returns the duplicates, and each scenario that uses the registry fails with them.
The same pattern in two phases is not a duplicate.

#### Phases and `*` steps <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_phases.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{
  and, asterisk, background, feature_with_background, given, scenario, then,
  when,
}
import dream_test/gherkin/steps.{type StepContext, Action, Check}
import dream_test/matchers.{be_equal, or_fail_with, should}

fn step_trip(_bag: Int, _context: StepContext) {
  Ok(0)
}

fn step_pack(bag: Int, _context: StepContext) {
  Ok(bag + 1)
}

fn step_close_bag(bag: Int, _context: StepContext) {
  Ok(bag)
}

fn step_bag_has_two(bag: Int, _context: StepContext) {
  bag
  |> should
  |> be_equal(2)
  |> or_fail_with("expected two things in the bag")
}

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given("I plan a trip", Action(step_trip))
    |> steps.given("I pack a passport", Action(step_pack))
    |> steps.given("I pack a toothbrush", Action(step_pack))
    |> steps.when_("I close the bag", Action(step_close_bag))
    |> steps.then_("the bag has 2 things", Check(step_bag_has_two))

  feature_with_background(
    "Packing",
    steps,
    background([given("I plan a trip")]),
    [
      scenario("Packing for a trip", [
        and("I pack a passport"),
        asterisk("I pack a toothbrush"),
        when("I close the bag"),
        then("the bag has 2 things"),
      ]),
    ],
  )
}
```

### `.feature` files (authoring + parsing)

If you want tests authored in plain text (often by QA/product, or copied from tickets), use real `.feature` files.

#### Example `.feature` file

##### The feature file <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/cart.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
@shopping
Feature: Shopping Cart
  As a customer I want to add items to my cart

  Background:
    Given the server is running

  @smoke
  Scenario: Adding items
    Given the cart is empty
    When I add 3 items
    Then the cart should have 3 items

  Scenario: Adding multiple times
    Given the cart is empty
    When I add 2 items
    And I add 3 items
    Then the cart should have 5 items
```

#### Loading a `.feature` file and converting to a suite

##### Load a feature file <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_file.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

pub type Cart {
  Cart(server_running: Bool, items: Int)
}

fn step_server_running(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, server_running: True))
}

fn step_empty_cart(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, items: 0))
}

fn step_add_items(cart: Cart, context: StepContext) {
  use to_add <- result.try(get_int(context.captures, 0))
  Ok(Cart(..cart, items: cart.items + to_add))
}

fn step_verify_count(cart: Cart, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.items
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define the steps and the state each scenario starts from
  let steps =
    steps.new(initial: Cart(server_running: False, items: 0))
    |> steps.given("the server is running", Action(step_server_running))
    |> steps.given("the cart is empty", Action(step_empty_cart))
    |> steps.when_("I add {int} items", Action(step_add_items))
    |> steps.then_("the cart should have {int} items", Check(step_verify_count))

  // Parse the .feature file
  let assert Ok(feature) = parser.parse_file("test/cart.feature")

  // Convert to TestSuite and run
  let config = FeatureConfig(feature: feature, step_registry: steps)
  to_test_suite(config)
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Rules, Examples sections and keyword synonyms

A `Rule` groups the scenarios that show one business rule.
A Rule can have its own Background.
The Feature Background steps run first, then the Rule Background steps, then the scenario steps.
So the first step of a Rule Background, or of a scenario in a Rule, can use `And`, `But` or `*` when a Background step runs before it.

A scenario can have more than one `Examples` section, and every row of every section runs.
The tags of an `Examples` section apply to the tests that its rows make.

#### A feature with Rules and two Examples sections <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/features/stock.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
@stock
Feature: Stock control
  The shop sells items from its stock.

  Background:
    Given the shop is open

  Rule: An item can be sold only when it is in stock

    Background:
      And the stock holds 5 items

    Example: Sell from stock
      When I sell 2 items
      Then the stock holds 3 items

    Scenario Outline: Sell different amounts
      When I sell <sold> items
      Then the stock holds <left> items

      @small
      Examples: Small orders
        | sold | left |
        | 1    | 4    |
        | 2    | 3    |

      @large
      Scenarios: Large orders
        | sold | left |
        | 5    | 0    |

  Rule: A sold-out shop sells nothing

    Background:
      * the stock holds 0 items

    Scenario: Nothing to sell
      Then the stock holds 0 items
```

#### Run the feature <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_rules.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

pub type Shop {
  Shop(open: Bool, stock: Int)
}

fn step_shop_open(shop: Shop, _context: StepContext) {
  Ok(Shop(..shop, open: True))
}

fn step_set_stock(shop: Shop, context: StepContext) {
  use count <- result.try(get_int(context.captures, 0))
  Ok(Shop(..shop, stock: count))
}

fn step_sell(shop: Shop, context: StepContext) {
  use sold <- result.try(get_int(context.captures, 0))
  Ok(Shop(..shop, stock: shop.stock - sold))
}

fn step_check_stock(shop: Shop, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  shop.stock
  |> should
  |> be_equal(expected)
  |> or_fail_with("Stock count mismatch")
}

pub fn tests() {
  let steps =
    steps.new(initial: Shop(open: False, stock: 0))
    |> steps.given("the shop is open", Action(step_shop_open))
    |> steps.given("the stock holds {int} items", Action(step_set_stock))
    |> steps.when_("I sell {int} items", Action(step_sell))
    |> steps.then_("the stock holds {int} items", Check(step_check_stock))

  // Each Rule becomes a group named "Rule: <name>".
  // Each Examples row becomes one test, for example
  // "Sell different amounts (Small orders, Example 1)".
  let assert Ok(feature) = parser.parse_file("test/features/stock.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
```

How the tests get their names and tags:

- Each Rule becomes a group named `Rule: <name>` (or `Rule:` when the Rule has no name). The full name of a scenario in a Rule is `Feature > Rule: <name> > Scenario`.
- Each Examples row becomes one test named `<scenario> (Example N)`. When the `Examples` section has a name, the test is named `<scenario> (<examples name>, Example N)`. N counts the rows of all `Examples` sections of the scenario, from 1, so each name is different.
- A scenario with no `Examples` section runs one time, also when its keyword is `Scenario Outline`. An `Examples` section with no table rows makes no tests.
- The tags of a test are the Feature tags, then the Rule tags, then the scenario tags, then the `Examples` tags. Tag filters see all of them.
- The values of an Examples row replace the `<header>` placeholders in the scenario name, the step texts, the DocStrings and the DataTable cells. The headers replace in column order.
- A scenario with no steps runs no Background steps.
- A step can have a DataTable and a DocString, in either order. The step function gets them in `context.table` and `context.doc_string`.

#### Test names of Rules and Examples <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_rule_names.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
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
        to_test_suite(FeatureConfig(
          feature: feature,
          step_registry: steps.new(initial: Nil),
        ))

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

The parser knows these English keywords and synonyms:

| Keyword | Synonyms |
|---|---|
| `Feature:` | `Business Need:`, `Ability:` |
| `Scenario:` | `Example:` |
| `Scenario Outline:` | `Scenario Template:` |
| `Examples:` | `Scenarios:` |
| DocString `"""` | DocString ```` ``` ```` |

A `# language:` line must name `en`, because the parser knows only English.

#### Parse errors

`parser.parse_string` returns a `ParseError(line, problem)`.
`parser.parse_file` returns a `FeatureFileError`: `UnreadableFeatureFile(error)` when the file cannot be read, or `InvalidFeatureFile(path, error)` when the text is not valid Gherkin.
`ParseProblem` has one variant for each kind of problem, for example `UnexpectedLine`, `InconsistentCellCount` or `MissingPreviousStep`.
Use `parser.feature_file_error_to_string` for a message such as `test/cart.feature: line 3: ...`.
`discover.load` gives the same `FeatureFileError` values in `LoadResult.errors`.

### Feature discovery (load `.feature` files)

Use discovery when you want real `.feature` files (e.g. written by QA or copied into tickets).

#### Discover feature files <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/gherkin/gherkin_discover.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

pub type Cart {
  Cart(server_running: Bool, items: Int)
}

fn step_server_running(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, server_running: True))
}

fn step_empty_cart(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, items: 0))
}

fn step_add_items(cart: Cart, context: StepContext) {
  use to_add <- result.try(get_int(context.captures, 0))
  Ok(Cart(..cart, items: cart.items + to_add))
}

fn step_verify_count(cart: Cart, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.items
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define the steps and the state each scenario starts from
  let steps =
    steps.new(initial: Cart(server_running: False, items: 0))
    |> steps.given("the server is running", Action(step_server_running))
    |> steps.given("the cart is empty", Action(step_empty_cart))
    |> steps.when_("I add {int} items", Action(step_add_items))
    |> steps.then_("the cart should have {int} items", Check(step_verify_count))

  // Discover and load all .feature files
  discover.features("test/*.feature")
  |> discover.with_registry(steps)
  |> discover.to_suite("cart_features")
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### What's Next?

- Go back to [Snapshot testing](09-snapshot-testing.md)
- Go back to [Documentation README](README.md)
- Continue to [Utilities](11-utilities.md)
