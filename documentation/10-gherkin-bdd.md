## Gherkin / BDD testing

### What is Gherkin?

**Gherkin** is a lightweight, plain-text format for writing **behavior-driven development (BDD)** specs. It’s commonly associated with tools like Cucumber, and it’s designed to be readable by both engineers and non-engineers.

At a high level, you describe behavior using a small vocabulary:

- **Feature**: a capability you’re describing (a suite of scenarios)
- **Scenario**: one concrete example (a test)
- **Background**: steps that run before each scenario of the Feature. They run again for every scenario. For a resource that starts one time for all scenarios, see [A setup for all scenarios](#a-setup-for-all-scenarios-for-example-a-server).
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
  - a `given` or `when` definition is an action: it gets the state and returns the new state, or an error
  - a `then` definition is a check: it gets the state and returns an assertion result. It cannot change the state.

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

- A `given` or `when` step (an action) returns `Ok(new_state)`, or `Error(message)` to fail the scenario.
- A `then` step (a check) returns an assertion result, like a unit test body. The next step gets the same state.

The `StepContext` fields:

- `context.captures`: the placeholder captures extracted from the step text
- `context.table`: the DataTable of the step, if any
- `context.doc_string`: the DocString of the step, if any
- `context.scenario_id`: the id of the scenario, for example `"Shopping Cart::Adding items#12"`. It is the name path of the scenario, then `#` and a number. The id is unique in the run, also for two scenarios with the same name. The number after `#` changes between runs, so do not use the id to key data that you keep between runs.

When a step fails, the steps after it do not run.

Important Gleam detail: when you access record fields like `context.captures`, Gleam needs to know the record type.
That’s why the examples annotate `context: StepContext` (it’s the minimal type hint needed for record field access).

The capture helpers (`get_int`, `get_float`, `get_string`, `get_word`) return a `Result`. Pass the error on with `use value <- result.try(get_int(context.captures, 0))`. Then a wrong capture fails the scenario with a message such as `Capture 0 is the word "apples", not an integer`. Do not use `result.unwrap`: the scenario then runs with a wrong value.

### Inline Gherkin (the “hero” example)

#### An inline feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_hero.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

What to notice in this example:

- The step registry is built once and shared by scenarios.
- The state is an `Int`. Each scenario starts from `0`, so scenarios don’t leak into each other.
- `context.captures` turns step text into typed values (via helpers like `get_int`).

### Placeholders (`{int}`, `{float}`, `{string}`, `{word}`)

Placeholders let you capture values from the step text into `context.captures`.
Typed helpers like `get_int` parse the capture into the right type.

- `{int}`: an integer, such as `42` or `-5`
- `{float}`: a number as Cucumber reads it: an optional sign, digits with an optional `.` and digits (or `.` and digits alone), and an optional exponent, such as `3.14`, `20`, `.5`, `-3` or `1.5e-3`. `5.`, `1,000` and `NaN` are not numbers. For a whole number, `{int}` wins over `{float}`, and `{float}` wins over `{word}` and `{}`.
- `{string}`: a double-quoted string, such as `"hello world"`. The capture has no quotes.
- `{word}`: text with no space, such as `alice` or `user42`
- `{}`: any text in one word

Step text and patterns are split into words at spaces. A double-quoted run stays in one word. A quoted run starts at a double quote at the start of a word, also after `(` or `[`. It ends at a double quote before a space, the end of the step, or one of `,` `.` `)` `]` `;` `:` `!` `?`. So `I add "apple", "banana"` matches `I add {string}, {string}`, and the quote in `O"Brien` or `5"` is an ordinary character. A placeholder can have text before or after it in the same word, such as `${float}USD`. A space in the pattern must be a space in the text. When more than one pattern matches a step, a literal word wins over a placeholder, and `{int}` wins over `{word}`. The module documentation of `dream_test/gherkin/step_trie` gives the full order.

#### Typed placeholders <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_placeholders.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, get_float, get_int, get_string, get_word,
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

// {float} captures numbers like 3.14, 20 or 1e5 (works with $ prefix too)
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
    |> steps.given("I have {int} items", step_int)
    |> steps.given("the price is ${float}", step_float)
    |> steps.given("the message is {string}", step_string)
    |> steps.given("the user is {word}", step_word)
    |> steps.then("everything works", step_everything_works)

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
Each step definition belongs to one phase. Register it with `steps.given`, `steps.when` or `steps.then`.
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
An inline feature that breaks these rules fails each scenario before any step runs. The failure message is the text of the parse problem, for example `"And a base" has no step before it. ...`.

Each pattern can have one step definition in each phase.
A second definition of the same pattern in the same phase is a duplicate.
`steps.validate` returns the duplicates, and each scenario that uses the registry fails with them.
The same pattern in two phases is not a duplicate.

#### Phases and `*` steps <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_phases.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{
  and, asterisk, background, feature_with_background, given, scenario, then,
  when,
}
import dream_test/gherkin/steps.{type StepContext}
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
    |> steps.given("I plan a trip", step_trip)
    |> steps.given("I pack a passport", step_pack)
    |> steps.given("I pack a toothbrush", step_pack)
    |> steps.when("I close the bag", step_close_bag)
    |> steps.then("the bag has 2 things", step_bag_has_two)

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

##### The feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/cart.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

##### Load a feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_file.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
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
    |> steps.given("the server is running", step_server_running)
    |> steps.given("the cart is empty", step_empty_cart)
    |> steps.when("I add {int} items", step_add_items)
    |> steps.then("the cart should have {int} items", step_verify_count)

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

A scenario in a Rule is in a group named `Rule: <name>` (or `Rule:` for a Rule with no name), under the Feature group. Its result kind is `GherkinScenario(scenario_id:, rule: Some("Rule: <name>"))`. A scenario outside a Rule has `rule: None`. The Gherkin reporter prints the Rule heading from this field, so a Feature named `Rule: refunds` prints as `Feature: Rule: refunds`.

A scenario can have more than one `Examples` section, and every row of every section runs.
The tags of an `Examples` section apply to the tests that its rows make.

#### A feature with Rules and two Examples sections <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/features/stock.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Run the feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_rules.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
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
    |> steps.given("the shop is open", step_shop_open)
    |> steps.given("the stock holds {int} items", step_set_stock)
    |> steps.when("I sell {int} items", step_sell)
    |> steps.then("the stock holds {int} items", step_check_stock)

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

#### Test names of Rules and Examples <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_rule_names.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
`FeatureFileError` has two more variants, which only discovery gives: `NoMatchingFeatureFiles(pattern)` when a pattern matches no files, and `InvalidFeatureFilePattern(pattern, reason)` when a pattern cannot be searched.
`ParseProblem` has one variant for each kind of problem, for example `UnexpectedLine`, `InconsistentCellCount` or `MissingPreviousStep`.
Use `parser.feature_file_error_to_string` for a message such as `test/cart.feature: line 3: ...`.
`discover.load` gives the same `FeatureFileError` values in `LoadResult.errors`.

### Feature discovery (load `.feature` files)

Use discovery when you want real `.feature` files (e.g. written by QA or copied into tickets).

#### Discover feature files <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_discover.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, get_int}
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
    |> steps.given("the server is running", step_server_running)
    |> steps.given("the cart is empty", step_empty_cart)
    |> steps.when("I add {int} items", step_add_items)
    |> steps.then("the cart should have {int} items", step_verify_count)

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

A relative pattern is read from the current directory. `gleam test` runs in the project directory, so `test/*.feature` finds the files in its `test` folder.

When the pattern finds no `.feature` file, the suite has no scenarios, so `to_suite` adds one failing test in their place:

- A pattern that matches no files gives the test `No feature files match the pattern "<pattern>"`, tagged `no-feature-files`.
- A pattern that cannot be searched, for example `features/{a.feature`, gives the test `Cannot search for feature files with the pattern "<pattern>": <reason>`, tagged `invalid-feature-pattern`.

`discover.load` gives the same problems as the errors `NoMatchingFeatureFiles(pattern)` and `InvalidFeatureFilePattern(pattern, reason)`.

### A setup for all scenarios (for example a server)

Some features need a resource that lives for all their scenarios, for example a server. Make the registry with `steps.new_with_setup` in place of `steps.new`:

- The setup runs one time, before the first scenario, and only when at least one scenario runs. A filter that keeps no scenario does not start the server.
- Each scenario starts from the value of the setup. A change that one scenario makes to its state does not reach the next scenario.
- The teardown gets the same value after the last scenario.
- The setup and the teardown run in one process that lives while the scenarios run. A process that the setup starts stays alive.
- The reports call them the *context setup* and the *context teardown*. The context setup runs once for each tree that has a scenario to run, before its first scenario, and its value is the starting state. The context teardown runs after the last scenario of that tree.
- When the process of the setup stops while the scenarios run, each scenario that did not start yet is `SetupFailed`. The run report gets a `types.SetupStopped` for the hook `context setup`, and its `not_run` lists those scenarios. The teardown still runs.
- When the setup returns `Error`, crashes or times out, each scenario is `SetupFailed` with the operator `context setup`, and the teardown does not run. A crash reads `the context setup crashed in Server: <reason>`. When the teardown fails, the run report gets a teardown failure for the hook `context teardown`, for example `context teardown in Server` then `the context teardown crashed in Server: <reason>`.

With `discover.to_suite`, the setup runs one time for the scenarios of all the files. A parse error test does not need the setup, so it runs without it.

#### The server <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L13-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// A small server: a process that answers each ping with "pong".

pub type Request {
  Ping(reply_to: Subject(String))
  Stop
}

pub type ServerState {
  ServerState(server: Subject(Request), reply: String)
}

fn start_server() -> Result(ServerState, String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  process.receive(started, 1000)
  |> result.replace_error("the server did not start")
  |> result.map(new_server_state)
}

fn stop_server(state: ServerState) -> Result(Nil, String) {
  process.send(state.server, Stop)
  Ok(Nil)
}

fn new_server_state(server: Subject(Request)) -> ServerState {
  ServerState(server: server, reply: "")
}

fn serve(started: Subject(Subject(Request))) -> Nil {
  let requests = process.new_subject()
  process.send(started, requests)
  answer(requests)
}

fn answer(requests: Subject(Request)) -> Nil {
  case process.receive_forever(requests) {
    Ping(reply_to: reply_to) -> {
      process.send(reply_to, "pong")
      answer(requests)
    }
    Stop -> Nil
  }
}
```

#### The steps with a setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L57-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// The steps. The setup starts the server once, before the first scenario.
// Each scenario starts from its value. The teardown stops the server after
// the last scenario.

fn server_steps() -> StepRegistry(ServerState) {
  steps.new_with_setup(setup: start_server, teardown: stop_server)
  |> steps.given("the server is running", server_is_running)
  |> steps.when("I ping the server", ping)
  |> steps.then("the reply is {string}", reply_is)
}

fn server_is_running(state: ServerState, _context: StepContext) {
  Ok(state)
}

fn ping(
  state: ServerState,
  _context: StepContext,
) -> Result(ServerState, String) {
  let reply = process.call(state.server, 1000, Ping)
  Ok(ServerState(..state, reply: reply))
}

fn reply_is(state: ServerState, context: StepContext) {
  use expected <- result.try(steps.get_string(context.captures, 0))
  state.reply
  |> should
  |> be_equal(expected)
  |> or_fail_with("the server should answer")
}
```

#### The feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L88-L101"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn server_feature() -> TestSuite {
  feature("Server", server_steps(), [
    scenario("Ping the server", [
      given("the server is running"),
      when("I ping the server"),
      then("the reply is \"pong\""),
    ]),
    scenario("Ping it again", [
      given("the server is running"),
      when("I ping the server"),
      then("the reply is \"pong\""),
    ]),
  ])
}
```

Each suite keeps its own context, so the feature runs in one `runner.new` with a `unit` suite and a `unit_context` suite:

#### One run with three kinds of suites <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L103-L132"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Suites with other contexts run in the same `runner.new`.

pub fn math_suite() -> TestSuite {
  unit.describe("Math", [
    unit.it("adds", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("1 + 1 should be 2")
    }),
  ])
}

pub fn counter_suite() -> TestSuite {
  unit_context.describe("Counter", 41, [
    unit_context.it("starts at 41", fn(count: Int) {
      count
      |> should
      |> be_equal(41)
      |> or_fail_with("the counter should start at 41")
    }),
  ])
}

pub fn main() {
  runner.new([server_feature(), math_suite(), counter_suite()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The run gives this output. The times change from run to run, and a test that takes less than 1ms shows no time:

```text
Feature: Server
  ✓ Scenario: Ping the server (1ms)
  ✓ Scenario: Ping it again (1ms)
Math
  ✓ adds
Counter
  ✓ starts at 41

Summary: 4 run, 0 failed, 4 passed in 2ms
```

#### Several Features with one setup

`discover.to_suite` runs one setup for all its files. To do the same with Features that you parse yourself, give each Feature to `steps.to_suite` as a `steps.SuiteFeature` child. Every scenario starts from the start of the registry: the initial state of `steps.new`, or the value of the setup of `steps.new_with_setup`. The setup runs one time for the scenarios of all its Features, and every scenario runs with the steps of that registry.

`steps.to_suite` takes these children (`steps.SuiteChild`):

- `SuiteFeature(feature)`: a group named after the Feature, with a test for each scenario.
- `SuiteScenarios(feature)`: the tests of the scenarios, with no group for the Feature. The tags of the Feature do not reach the scenarios. The Gherkin reporter takes the name of the nearest group, for example the suite name, as the `Feature:` heading.
- `SuiteGroup(name:, tags:, children:)`: a group of your own, for example with a tag, that holds more children.
- `SuiteNode(node)`: a test, a hook or a group that you make, for example with `unit_context.it` or `unit_context.before_each`. It gets the same start as the scenarios.

A Feature gets its tests only from the registry of its suite, so it cannot run with the steps of one registry and the setup of another. To use two registries, make two suites, for example with `suite.join`: each setup runs one time for its own Features.

##### Two Features, one setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_shared_setup.gleam#L39-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn shop_steps() -> StepRegistry(Int) {
  steps.new_with_setup(setup: open_shop, teardown: close_shop)
  |> steps.then("the shop has {int} items", has_items)
}

/// Two Features in one suite: the setup runs one time for both.
fn shop_suite(cart: types.Feature, stock: types.Feature) -> TestSuite {
  steps.to_suite(registry: shop_steps(), name: "Shop", tags: [], children: [
    SuiteFeature(cart),
    SuiteGroup(name: "Warehouse", tags: ["warehouse"], children: [
      SuiteFeature(stock),
    ]),
  ])
}
```

In this example, `types` is `dream_test/gherkin/types`. `parser.parse_file` and `parser.parse_string` give a `types.Feature`.

### What's Next?

- Go back to [Snapshot testing](09-snapshot-testing.md)
- Go back to [Documentation README](README.md)
- Continue to [Utilities](11-utilities.md)
