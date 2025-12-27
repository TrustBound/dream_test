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

In Dream Test, you write Gherkin either as standard `.feature` files or directly in Gleam, and you implement behavior by mapping step text to handler functions (a “step registry”).

Unit tests are great for “input → output.” Gherkin is for “a sequence of behavior over time.”

This chapter explains Dream Test’s Gherkin layer as an engineering tool:

- It’s for scenarios with shared per-scenario state (“the world”)
- It’s for readable specs you can share with product/QA
- It’s for reusing step definitions across many scenarios

### Mental model

- A **scenario** is a test.
- Each scenario runs with its own `StepContext`:
  - `context.world` is per-scenario state (isolated)
  - `context.captures` holds placeholder captures from the step text
- A **step registry** maps text patterns to handler functions.

Dream Test includes a Gherkin DSL that lets you write scenarios with **Given/When/Then** structure.

### When to use Gherkin

- You want tests that are readable by non-engineers (product, QA, support).
- You want to model behavior as scenarios with a shared “world” state.
- You want to reuse step definitions across many scenarios.

If your tests are mostly “function input → output”, the unit DSL (`describe` / `it`) is usually simpler.

### The core pieces

- **Feature**: a suite of scenarios
- **Scenario**: a list of steps (Given/When/Then/And/But)
- **Step registry**: maps step patterns to handlers
- **World**: per-scenario state (isolated between scenarios)
- **Captures**: placeholder values parsed from step text

### Step handlers and `StepContext` (the “context” you were missing)

Each step handler receives a `StepContext` record. The two fields you use most often are:

- `context.world`: a per-scenario key/value store (isolated between scenarios)
- `context.captures`: the placeholder captures extracted from the step text

Important Gleam detail: when you access record fields like `context.world`, Gleam needs to know the record type.
That’s why the examples annotate `context: StepContext` (it’s the minimal type hint needed for record field access).

### Inline Gherkin (the “hero” example)

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/gherkin/gherkin_hero.gleam)</sub>

What to notice in this example:

- The step registry is built once and shared by scenarios.
- `context.world` is per-scenario state, so scenarios don’t leak into each other.
- `context.captures` turns step text into typed values (via helpers like `get_int`).

### Placeholders (`{int}`, `{float}`, `{string}`, `{word}`)

Placeholders let you capture values from the step text into `context.captures`.
Typed helpers like `get_int` parse the capture into the right type.

```gleam
import dream_test/matchers.{succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, get_float, get_int, get_string, get_word, step,
}
import dream_test/gherkin/world.{put}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

// {int} captures integers
fn step_int(context: StepContext) {
  let value = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "int", value)
  Ok(succeed())
}

// {float} captures decimals (works with $ prefix too)
fn step_float(context: StepContext) {
  let value = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "float", value)
  Ok(succeed())
}

// {string} captures quoted strings
fn step_string(context: StepContext) {
  let value = get_string(context.captures, 0) |> result.unwrap("")
  put(context.world, "string", value)
  Ok(succeed())
}

// {word} captures a single unquoted word
fn step_word(context: StepContext) {
  let value = get_word(context.captures, 0) |> result.unwrap("")
  put(context.world, "word", value)
  Ok(succeed())
}

fn step_pass(_context) {
  Ok(succeed())
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items", step_int)
    |> step("the price is ${float}", step_float)
    |> step("the message is {string}", step_string)
    |> step("the user is {word}", step_word)
    |> step("everything works", step_pass)

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/gherkin/gherkin_placeholders.gleam)</sub>

### `.feature` files (authoring + parsing)

If you want tests authored in plain text (often by QA/product, or copied from tickets), use real `.feature` files.

#### Example `.feature` file

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

<sub>🧪 [Tested source](../examples/snippets/test/cart.feature)</sub>

#### Loading a `.feature` file and converting to a suite

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

fn step_empty_cart(context: StepContext) {
  put(context.world, "cart", 0)
  Ok(succeed())
}

fn step_server_running(context: StepContext) {
  put(context.world, "server_running", True)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define step handlers
  let steps =
    steps.new()
    |> step("the server is running", step_server_running)
    |> step("the cart is empty", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/gherkin/gherkin_file.gleam)</sub>

### Feature discovery (load `.feature` files)

Use discovery when you want real `.feature` files (e.g. written by QA or copied into tickets).

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

fn step_empty_cart(context: StepContext) {
  put(context.world, "cart", 0)
  Ok(succeed())
}

fn step_server_running(context: StepContext) {
  put(context.world, "server_running", True)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define step handlers
  let steps =
    steps.new()
    |> step("the server is running", step_server_running)
    |> step("the cart is empty", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/gherkin/gherkin_discover.gleam)</sub>

### What's Next?

- Go back to [Snapshot testing](09-snapshot-testing.md)
- Go back to [Documentation README](README.md)
- Continue to [Utilities](11-utilities.md)
