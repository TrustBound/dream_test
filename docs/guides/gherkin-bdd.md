# Write Gherkin features

Some behavior is a story, not a function call: a customer fills a cart, checks out, gets a receipt. You want the test to read like that story, so a product owner or a tester can read it, change it, or write the next one. Gherkin is the plain-text format for such stories, and Dream Test runs it: you write Feature, Scenario, Given, When and Then, in a `.feature` file or in Gleam, and map each step to a typed Gleam function. This guide takes you from a first feature to feature files, Rules and Examples, a server that runs once for all scenarios, and tests for your step functions.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How Gherkin runs in Dream Test](#how-gherkin-runs-in-dream-test)
- [Where to write the features](#where-to-write-the-features)
- [Step 1: Write a feature in Gleam](#step-1-write-a-feature-in-gleam)
- [Step 2: Write the steps as named functions](#step-2-write-the-steps-as-named-functions)
- [Step 3: Move the feature to a .feature file](#step-3-move-the-feature-to-a-feature-file)
- [Step 4: Load every feature file of a folder](#step-4-load-every-feature-file-of-a-folder)
- [Step 5: Use Backgrounds, Rules and Examples](#step-5-use-backgrounds-rules-and-examples)
- [Step 6: Start a server once for all scenarios](#step-6-start-a-server-once-for-all-scenarios)
- [When a scenario fails](#when-a-scenario-fails)
- [When a feature doesn't parse](#when-a-feature-doesnt-parse)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Write a shopping cart feature in Gleam, run it, and read the Gherkin report.
- Write step functions that capture numbers from the step text.
- Run the same feature from a `.feature` file, then every `.feature` file of a folder.
- Use a Background, Rules and Examples tables, and see the test names they give.
- Start a server once for all scenarios, and run it next to other suites.
- Read the report of a failing check, an undefined step, a step that crashes and a parse error, with the step and its line.
- Test your step functions on their own.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## How Gherkin runs in Dream Test

Gherkin has a small vocabulary:

- A **Feature** is a capability, with its scenarios. It becomes a group of tests.
- A **Scenario** is one example of the behavior. It becomes one test.
- A **step** is one line of a scenario: **Given** a starting state, **When** an action, **Then** an expected outcome. `And`, `But` and `*` continue the step before them.
- A **Background** holds steps that run before each scenario of its Feature or Rule.

Dream Test adds two ideas:

- **The state.** Each feature has one state type that you choose, such as an `Int` or a `Cart` record. Each scenario starts from an initial value of it, in its own process. The state is an immutable value, so one scenario can't leak into the next.
- **The step registry.** It maps step text patterns to Gleam functions, one phase for each function. A Given or When function is an *action*: it gets the state and returns the new state, or an error. A Then function is a *check*: it gets the state and returns an assertion, like a unit test body, and can't change the state.

## Where to write the features

| Your situation | Use | Why |
|:---|:---|:---|
| Engineers write and read the scenarios | A feature in Gleam, with `dream_test/gherkin/feature` | The compiler checks the structure, and everything lives in one file. |
| Product owners or testers write the scenarios | A `.feature` file, loaded with `parser.parse_file` and `steps.feature_suite` | Plain text that anyone can edit, and that other Gherkin tools read too. |
| Many `.feature` files in a folder | `dream_test/gherkin/discover` | One registry runs every file, and a new file runs without a code change. |
| The behavior is input and output of one function | A unit test, `describe` and `it` | Gherkin pays off for a sequence of steps, not for one call. |

## Step 1: Write a feature in Gleam

Here's the whole thing in one module: the steps, the feature and its one scenario.

### The shopping cart feature in Gleam <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/readme/gherkin_inline.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given("I have {int} items", fn(_cart: Int, context: StepContext) {
      get_int(context.captures, 0)
    })
    |> steps.when("I add {int} more", fn(cart: Int, context: StepContext) {
      use added <- result.try(get_int(context.captures, 0))
      Ok(cart + added)
    })
    |> steps.then(
      "I should have {int} items",
      fn(cart: Int, context: StepContext) {
        use expected <- result.try(get_int(context.captures, 0))
        cart
        |> should
        |> be_equal(expected)
        |> or_fail_with("Cart count mismatch")
      },
    )

  feature("Shopping Cart", steps, [
    scenario("Adding items", [
      given("I have 3 items"),
      when("I add 2 more"),
      then("I should have 5 items"),
    ]),
  ])
}
```

What it does:

- `steps.new(initial: 0)` makes a registry whose state is an `Int`, and each scenario starts from `0`.
- `steps.given`, `steps.when` and `steps.then` register a pattern for one phase. `{int}` is a placeholder: it captures a number from the step text.
- `get_int(context.captures, 0)` reads the first capture as an `Int`. It returns a `Result`, so a capture of the wrong type fails the scenario with a clear message.
- `feature(name, steps, scenarios)` builds a `TestSuite`, and `scenario` and the `given`, `when` and `then` helpers build the steps. There are also `and`, `but`, `asterisk`, `background`, `feature_with_background` and `with_tags`.

`tests()` returns a normal suite, so any runner runs it, with any reporter. The Gherkin reporter prints it in the Cucumber style. Give `gherkin.format` from `dream_test/reporters/gherkin` to the runner as `reporter_types.Custom(gherkin.format)`:

### The Gherkin report of the feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_gherkin_inline.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Feature: Shopping Cart
  Scenario: Adding items ✓

Summary: 1 run, 0 failed, 1 passed in 0ms
```

## Step 2: Write the steps as named functions

Anonymous step functions get long fast. Name them, and the registry reads as a list of sentences:

### The cart steps as named functions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/gherkin_cart_steps.gleam#L12-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn cart_steps() -> StepRegistry(Int) {
  steps.new(initial: 0)
  |> steps.given("I have {int} items in my cart", have_items)
  |> steps.when("I add {int} more items", add_items)
  |> steps.then("I should have {int} items total", should_have_items)
}

pub fn have_items(_cart: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

pub fn add_items(cart: Int, context: StepContext) -> Result(Int, String) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(cart + added)
}

fn should_have_items(cart: Int, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart
  |> should
  |> be_equal(expected)
  |> or_fail_with("the cart should hold the expected number of items")
}
```

Each step function gets two arguments: the state, and a `StepContext` record with these fields:

- `captures`: the placeholder values from the step text, in order.
- `table`: the DataTable of the step, if it has one.
- `doc_string`: the DocString of the step, if it has one.
- `scenario_id`: the id of the scenario, such as `"Shopping Cart::Adding items#12"`: the name path of the scenario, then `#` and a number. It's unique in the run, also for two scenarios with the same name, so you can use it to name rows or files that no other scenario uses. The number changes between runs, so don't key data you keep between runs on it.

When a step fails, the steps after it don't run. Annotate `context: StepContext` when you read its fields, because Gleam needs the record type for field access.

The placeholders:

| Placeholder | Matches | Read it with |
|:---|:---|:---|
| `{int}` | An integer, such as `42` or `-5` | `get_int` |
| `{float}` | A number as Cucumber reads it, such as `3.14`, `20`, `.5`, `-3` or `1.5e-3` | `get_float` |
| `{string}` | A double-quoted string, such as `"hello world"`. The capture has no quotes. | `get_string` |
| `{word}` | Text with no space, such as `alice` | `get_word` |
| `{}` | Any text in one word | `get_word` |

Step text and patterns split into words at spaces, and a double-quoted run stays one word. A placeholder can have text around it in the same word, such as `${float}USD`. When more than one pattern matches, a literal word wins over a placeholder, and `{int}` wins over `{float}`, which wins over `{word}` and `{}`. The [reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#gherkin-step-matching) has the full matching rules.

Each pattern can have one definition in each phase. A second definition of the same pattern in the same phase is a duplicate: `steps.validate(registry)` returns it, and each scenario that uses the registry fails with `Duplicate step definition: ...`. The same pattern in two phases is fine.

## Step 3: Move the feature to a .feature file

When people outside the code write scenarios, put them in a `.feature` file. This file holds the same scenario as Step 1:

### The shopping cart feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/features/shopping_cart.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
```

Parse the file and give it to `steps.feature_suite` with the registry:

### The steps for the shopping cart feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/readme/gherkin_file.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, feature_suite, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

fn step_have_items(_cart: Int, context: StepContext) {
  get_int(context.captures, 0)
}

fn step_add_items(cart: Int, context: StepContext) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(cart + added)
}

fn step_verify_count(cart: Int, context: StepContext) {
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
    |> steps.then("I should have {int} items total", step_verify_count)

  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")
  feature_suite(registry: steps, feature: feature)
}
```

`parser.parse_file` reads a path relative to the project folder, where `gleam test` runs. It returns `Ok(Feature)`, or a `FeatureFileError`: `UnreadableFeatureFile(error)` when the file can't be read, or `InvalidFeatureFile(path, error)` when the text isn't valid Gherkin. `parser.feature_file_error_to_string` turns it into a message such as `test/cart.feature: line 3: ...`. `steps.feature_suite(registry:, feature:)` gives a suite whose top-level group is the Feature.

## Step 4: Load every feature file of a folder

Discovery loads every `.feature` file that a pattern matches, and runs them all with one registry. This module loads `test/*.feature`:

### Discover feature files <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_discover.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

One of the files it loads:

### A feature file that discovery loads <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/cart.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

How it works:

- `discover.features(pattern)` finds the files. A relative pattern is read from the project folder, so `test/*.feature` finds the files in `test`.
- `discover.with_registry(steps)` gives them the registry, and `discover.to_suite(name)` makes one suite named `name`, with a group for each Feature.
- A file that doesn't parse becomes a failing test that names the file and the line, and the other files still run.
- A pattern that matches no file gives one failing test, `No feature files match the pattern "<pattern>"`, tagged `no-feature-files`. A pattern that can't be searched, such as `features/{a.feature`, gives `Cannot search for feature files with the pattern "<pattern>": <reason>`, tagged `invalid-feature-pattern`.
- `discover.load` gives the parsed features and the errors as values, and `discover.list_files` gives the matching paths, as `Ok(paths)` or `Error(parser.InvalidFeatureFilePattern(pattern, reason))`.

## Step 5: Use Backgrounds, Rules and Examples

Real features have structure: steps every scenario shares, business rules that group scenarios, and tables of examples. This feature has all three:

### A feature with Rules and two Examples sections <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/features/stock.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

A Background's steps run before each scenario of its Feature or Rule, again for every scenario. The Feature Background runs first, then the Rule Background, then the scenario. The Background steps get the initial state, and the scenario gets the state they leave. A scenario with no steps runs no Background steps.

A Rule becomes a group named `Rule: <name>`, under the Feature. Each row of an `Examples` table becomes one test named `<scenario> (Example N)`, or `<scenario> (<examples name>, Example N)` when the section has a name, and the row's values replace the `<header>` placeholders in the scenario name, the steps, the DocStrings and the DataTables. N counts the rows of all `Examples` sections of the scenario, from 1. This module runs the feature and checks the names:

### Test names of Rules and Examples <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_rule_names.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

The phases follow a few rules:

- `And`, `But` and `*` take the phase of the step before them. Use `*` for a list of steps where Given, When or Then reads badly.
- The first step of a Background must be Given, When or Then. So must the first step of a scenario, unless a Background step runs before it: then it can start with `And`, `But` or `*`, which takes the phase of the last Background step.
- A step matches only the definitions of its phase, so a Given definition never runs for a When step.

The tags of a test are the Feature tags, then the Rule tags, then the scenario tags, then the `Examples` tags, and tag filters see all of them. A scenario with no `Examples` runs once, even with the keyword `Scenario Outline`, and an `Examples` section with no rows makes no tests. The [reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#gherkin-keywords) lists every keyword and its synonyms.

## Step 6: Start a server once for all scenarios

Some features need a resource that lives for all their scenarios, such as a server. Make the registry with `steps.new_with_setup` in place of `steps.new`. Here's a small server, a process that answers each ping with "pong":

### The server <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L16-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

The registry starts it in its setup and stops it in its teardown:

### The steps with a setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L60-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### The feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L91-L104"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

How the setup runs. The reports call it the *context setup*, and the teardown the *context teardown*:

- The setup runs once, before the first scenario, and only when at least one scenario runs. A filter that keeps no scenario doesn't start the server.
- Each scenario starts from the value of the setup. A change one scenario makes to its state doesn't reach the next.
- The teardown gets the same value after the last scenario.
- The setup and the teardown run in one process that lives while the scenarios run, so a process the setup starts stays alive.
- If the setup returns `Error`, crashes or times out, each scenario is `SetupFailed` with the operator `context setup`, and the teardown doesn't run. A crash reads `the context setup crashed in Server: <reason>`. If the teardown fails, the run report gets a teardown failure for the hook `context teardown`.
- If the process of the setup stops while the scenarios run, each scenario that hadn't started is `SetupFailed`, the run report gets a `types.SetupStopped` for the hook `context setup`, and the teardown still runs.

With `discover.to_suite`, the setup runs once for the scenarios of all the files. A parse error test doesn't need the setup, so it runs without it.

The feature is a `TestSuite` like any other, so it runs in one `runner.new` with a `unit` suite and a `unit_context` suite:

### One run with three kinds of suites <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_setup.gleam#L106-L135"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Suites whose trees have other contexts run in the same `runner.new`.

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
  unit_context.describe("Counter", context.value(41), [
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

### The report of the three suites <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/gherkin_setup_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Feature: Server
  ✓ Scenario: Ping the server
  ✓ Scenario: Ping it again
Math
  ✓ adds
Counter
  ✓ starts at 41

Summary: 4 run, 0 failed, 4 passed in 0ms
```

The BDD reporter prints `Feature: <name>` on the group of a Feature, and plain names on other groups.

To share one setup between several Features that you parse yourself, give each one to `steps.to_suite` as a `steps.Feature` test. The setup runs once for the scenarios of all of them:

### Two Features, one setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/gherkin/gherkin_shared_setup.gleam#L39-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn shop_steps() -> StepRegistry(Int) {
  steps.new_with_setup(setup: open_shop, teardown: close_shop)
  |> steps.then("the shop has {int} items", has_items)
}

/// Two Features in one suite: the setup runs one time for both.
fn shop_suite(cart: types.Feature, stock: types.Feature) -> TestSuite {
  steps.to_suite(registry: shop_steps(), name: "Shop", tags: [], tests: [
    Feature(cart),
    Group(name: "Warehouse", tags: ["warehouse"], tests: [
      Feature(stock),
    ]),
  ])
}
```

`types` here is `dream_test/gherkin/types`. `steps.to_suite` takes these tests (`steps.SuiteTest`):

- `Feature(feature)`: a group named after the Feature, with a test for each scenario.
- `Scenarios(feature)`: the tests of the scenarios, with no group for the Feature. The Feature's tags don't reach them, and their result kind has `feature: None`. The Gherkin reporter prints the groups around them, joined with ` > `, as their heading, such as `Shop > Billing`.
- `Group(name:, tags:, tests:)`: a group of your own that holds more tests.
- `Node(node)`: a test, a hook or a group you make, for example with `unit_context.it`. It gets the same start as the scenarios.

A Feature gets its steps only from the registry of its suite. To use two registries, make two suites, for example with `suite.join`: each setup then runs once for its own Features.

## When a scenario fails

Here are two scenarios that fail in the two ways scenarios fail most: a check that doesn't hold, and a step that no definition matches.

### A feature with two failing scenarios <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/gherkin_cart_steps.gleam#L39-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn failing_feature() -> TestSuite {
  feature("Shopping Cart", cart_steps(), [
    scenario("Adding items", [
      given("I have 3 items in my cart"),
      when("I add 1 more items"),
      then("I should have 5 items total"),
    ]),
    scenario("Removing items", [
      given("I have 3 items in my cart"),
      when("I remove 1 item"),
      then("I should have 2 items total"),
    ]),
  ])
}
```

### The Gherkin report of the failures <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_gherkin_failures.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Feature: Shopping Cart
  Scenario: Adding items ✗
      ✗ be_equal
        Step: Then I should have 5 items total
        Message: the cart should hold the expected number of items
        Expected: 5
        Actual:   4
      Run it alone: gleam test -- --only "Shopping Cart/Adding items"
  Scenario: Removing items ✗
      ✗ step
        Step: When I remove 1 item
        Message: Undefined step: When I remove 1 item
      Run it alone: gleam test -- --only "Shopping Cart/Removing items"

Summary: 2 run, 2 failed, 0 passed in 0ms
```

Each failure starts with its operator. Then the `Step:` line names the step that failed, with its keyword and text as the feature writes them. The first scenario ran every step, and the check of `Then I should have 5 items total` failed with the values. The second stopped at `When I remove 1 item`: no When definition matches it, so the scenario fails with the operator `step` and `Undefined step:` and the step, and the steps after it don't run. Add the definition, or fix the text of the step.

### Find the failing step in a feature file

When the scenarios come from a `.feature` file, the `Step:` line also names the file and the line of the step. This file holds the two failing scenarios, and a third scenario with a step that crashes:

#### The failing feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/features/shopping_cart_failures.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 1 more items
    Then I should have 5 items total

  Scenario: Removing items
    Given I have 3 items in my cart
    When I remove 1 item
    Then I should have 2 items total

  Scenario: Breaking the cart
    Given I have 3 items in my cart
    When the cart breaks
    Then I should have 3 items total
```

The registry adds a When step that panics:

#### Load the failing feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/gherkin_file_failures.gleam#L15-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn failing_feature_file() -> TestSuite {
  let registry =
    cart_steps()
    |> steps.when("the cart breaks", break_cart)
  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart_failures.feature")
  steps.feature_suite(registry: registry, feature: feature)
}

fn break_cart(_cart: Int, _context: StepContext) -> Result(Int, String) {
  panic as "the cart broke"
}
```

#### The Gherkin report of the feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_gherkin_file_failures.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Feature: Shopping Cart
  Scenario: Adding items ✗
      ✗ be_equal
        Step: Then I should have 5 items total (test/features/shopping_cart_failures.feature:5)
        Message: the cart should hold the expected number of items
        Expected: 5
        Actual:   4
      Run it alone: gleam test -- --only "Shopping Cart/Adding items"
  Scenario: Removing items ✗
      ✗ step
        Step: When I remove 1 item (test/features/shopping_cart_failures.feature:9)
        Message: Undefined step: When I remove 1 item
      Run it alone: gleam test -- --only "Shopping Cart/Removing items"
  Scenario: Breaking the cart ✗
      ✗ crash
        Step: When the cart breaks (test/features/shopping_cart_failures.feature:14)
        Message: error:#{function => <<"break_cart">>,line => 25,
        message => <<"the cart broke">>,
        module => <<"snippets/guides/gherkin_file_failures">>,
        file => <<"test/snippets/guides/gherkin_file_failures.gleam">>,
        gleam_error => panic}
      Run it alone: gleam test -- --only "Shopping Cart/Breaking the cart"

Summary: 3 run, 3 failed, 0 passed in 0ms
```

The three failures read alike: the operator (`be_equal` for the check, `step` for the undefined step, `crash` for the step that crashed), the step with `(<file>:<line>)`, then the message. A crash in a step stops the scenario at that step, and its message is the crash reason. An inline feature has no file, and a feature from `parser.parse_string` gives `(line N)`. The BDD reporter shows the same `Step:` line, and the JSON report has the step as a `step` object in the failure.

## When a feature doesn't parse

The parser follows the official Gherkin grammar, and a mistake gives an error that names the line. This feature starts its scenario with `And`:

### A feature that starts with And <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/gherkin_parse_error.gleam#L8-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// A feature whose first scenario step is `And`, with no step before it.
pub const broken_feature =
  "Feature: Shopping Cart
  Scenario: Adding items
    And I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
"

pub fn parse_broken_feature() -> Result(Feature, String) {
  parser.parse_string(broken_feature)
  |> result.map_error(parser.parse_error_to_string)
}
```

`parse_broken_feature()` returns this error:

### The parse error <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_gherkin_parse_error.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
line 3: "And I have 3 items in my cart" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.
```

`parser.parse_string` returns a `ParseError(line, problem)`, and `parser.parse_error_to_string` gives this text, which starts with `line N:`. A `.feature` file with the same mistake fails to load with the path in front: `test/cart.feature: line 3: ...`. An inline feature with the mistake fails each scenario before any step runs, with the same text.

## Test your code

Step functions are plain functions of a state and a `StepContext`, so you can test them without a feature. Build a `StepContext` by hand, with the captures the step expects, and check the result. Check the registry too: `steps.validate` finds duplicate definitions before a scenario does.

### Tests for the cart steps <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/gherkin_step_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/step_trie.{CapturedInt, CapturedWord}
import dream_test/gherkin/steps.{StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guides/gherkin_cart_steps.{add_items, cart_steps}

fn context_with(captures) {
  StepContext(
    captures: captures,
    table: None,
    doc_string: None,
    scenario_id: "Shopping Cart::Adding items#1",
  )
}

pub fn tests() {
  describe("The cart steps", [
    it("have no duplicate definition", fn() {
      // Act
      let problems = steps.validate(cart_steps())

      // Assert
      problems
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("each pattern should have one definition per phase")
    }),
    it("add the captured number of items", fn() {
      // Act
      let cart = add_items(3, context_with([CapturedInt(2)]))

      // Assert
      cart
      |> should
      |> be_equal(Ok(5))
      |> or_fail_with("3 items and 2 more should be 5")
    }),
    it("fail on a capture that is not a number", fn() {
      // Act
      let cart = add_items(3, context_with([CapturedWord("two")]))

      // Assert
      cart
      |> should
      |> be_equal(Error("Capture 0 is the word \"two\", not an integer"))
      |> or_fail_with("a word should not count as items")
    }),
  ])
}
```

The third test shows why `get_int` returns a `Result`: a capture of the wrong kind becomes an `Error` with a clear message, not a wrong number. The report:

### The report of the step tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_gherkin_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The cart steps
  ✓ have no duplicate definition
  ✓ add the captured number of items
  ✓ fail on a capture that is not a number

Summary: 3 run, 0 failed, 3 passed in 0ms
```

## Common pitfalls

**`result.unwrap` on a capture.** *Symptom:* a scenario runs with `0` where the text said `"two"`, and passes or fails for the wrong reason. *Fix:* use `use value <- result.try(get_int(context.captures, 0))`, so a wrong capture fails the scenario with `Capture 0 is the word "two", not an integer`.

**A step pattern with a space that the text doesn't have.** *Symptom:* `Undefined step` for text that looks right, such as `$19.99` against `$ {float}`. *Fix:* a space in the pattern must be a space in the text. Write `${float}`.

**State kept between scenarios.** *Symptom:* a scenario passes alone and fails after another. *Fix:* the state starts fresh in each scenario. Keep shared resources in the setup of `steps.new_with_setup`, and anything a scenario needs in its own steps or Background.

**A discovery pattern that matches nothing.** *Symptom:* one failing test, `No feature files match the pattern`. *Fix:* the pattern is relative to the project folder, so write `test/features/*.feature`, not `features/*.feature`.

**Comparing scenario ids between runs.** *Symptom:* a tool that keys data on `scenario_id` loses it every run. *Fix:* the number after `#` changes between runs. Use the name path.

## Where to go next

- [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md): the same setup idea for unit tests.
- [Choose and read the test output](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md): the Gherkin reporter next to the others.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#gherkin-keywords): keywords, matching rules and parse errors.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/gherkin/steps.html): `steps`, `feature`, `parser`, `discover` and `types`.
