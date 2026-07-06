<div align="center">
  <img src="./ricky_and_lucy.png" alt="Dream Test logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>Feature-rich unit and integration testing for Gleam.</strong></p>

  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation">
  </a>
  <a href="./LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  </a>
</div>

<br>

## Install Dream Test

```sh
gleam add --dev dream_test
```

Current version: `2.1.2`

## Why Dream Test?

Rapid application development needs testing tools that scale and support the growing needs of the application without slowing down progress. Dream test was designed to help engineers write expressive unit and integration tests for their applications using the tools and techniques they know from other ecosystems; adapted properly to gleam and the beam.

### Test Styles

| Feature                 | What you get                                     |
| ----------------------- | ------------------------------------------------ |
| 🧪 **Unit tests**       | `describe`/`group`/`it` for organizing tests     |
| 🥒 **Gherkin specs**    | `.feature` files or inline Gleam DSL             |
| 📸 **Snapshot testing** | Lock in complex output without manual assertions |

### Assertions

| Feature                      | What you get                                                      |
| ---------------------------- | ----------------------------------------------------------------- |
| ⛓️ **Pipe-first assertions** | Matchers that chain and compose                                   |
| 📦 **Built-in matchers**     | Equality, booleans, options, results, lists, strings, comparisons |
| 🎁 **Unwrapping matchers**   | Option/Result matchers that unwrap for continued assertion        |
| 🛠️ **Custom matchers**       | Write your own for your domain                                    |

### Test Organization

| Feature                    | What you get                                           |
| -------------------------- | ------------------------------------------------------ |
| 🔄 **Lifecycle hooks**     | `before_all`, `after_all`, `before_each`, `after_each` |
| 🔗 **Context-aware tests** | Shared setup across tests with `unit_context`          |
| 🏷️ **Tags**                | Filter and organize test runs                          |

### Execution

| Feature                                | What you get                                                                                              |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| ⚡ **Parallel execution**              | Configurable concurrency for fast runs                                                                    |
| 🛡️ **Isolation**                       | Crashes and timeouts don't break the run                                                                  |
| ⏱️ **Timeouts**                        | Per-test timeout control                                                                                  |
| 🔍 **Test discovery**                  | Find tests from file paths                                                                                |
| 🚨 **Exit-on-failure**                 | Fail fast for CI                                                                                          |
| 🪝 **Runner hooks**                    | Runner-level hooks for per-test/per-suite/per-run setup and teardown                                       |
| 🧩 **Suite-specific execution config** | Run some suites sequential/with custom timeouts in the same runner (`runner.add_suites_with_config(...)`) |

### Reporting

| Feature                      | What you get                                         |
| ---------------------------- | ---------------------------------------------------- |
| 📝 **BDD results reporter**  | Human-readable, hierarchical output (printed at end) |
| 📊 **Progress reporter**     | Live single-line progress bar during the run         |
| 📋 **JSON results reporter** | Machine-readable JSON (printed at end)               |
| 🌿 **Gherkin formatting**    | Dedicated output for feature tests                   |

Dream Test splits reporting into:

- **Progress** (during the run): `runner.progress_reporter(progress.new())`
- **Results** (after the run): `runner.results_reporters([bdd.new(), json.new(), ...])`

## Full Usage Guide

1. [Installation](documentation/01-installation.md)
2. [Quick Start](documentation/02-quick-start.md)
3. [Writing Tests](documentation/03-writing-tests.md)
4. [Context-Aware Tests](documentation/04-context-aware-tests.md)
5. [Assertions & Matchers](documentation/05-assertions-and-matchers.md)
6. [Lifecycle Hooks](documentation/06-lifecycle-hooks.md)
7. [Runner & Execution](documentation/07-runner-and-execution.md) — includes runner hooks
8. [Reporters](documentation/08-reporters.md)
9. [Snapshot Testing](documentation/09-snapshot-testing.md)
10. [Gherkin BDD](documentation/10-gherkin-bdd.md)
11. [Utilities](documentation/11-utilities.md)

## Unit Tests

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      "  hello  "
      |> string.trim()
      |> should
      |> be_equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
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

<sub>🧪 [Tested source](examples/snippets/test/snippets/unit/quick_start.gleam) · 📖 [Guide](documentation/02-quick-start.md)</sub>

## Gherkin Integration Tests

```gherkin
Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
```

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

fn step_have_items(context: StepContext) {
  put(context.world, "cart", get_int(context.captures, 0) |> result.unwrap(0))
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  put(context.world, "cart", current + { get_int(context.captures, 0) |> result.unwrap(0) })
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(get_int(context.captures, 0) |> result.unwrap(0))
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_verify_count)

  let assert Ok(feature) = parser.parse_file("test/shopping_cart.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/gherkin/gherkin_file.gleam) · 📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

## Gherkin Syntax in Gleam

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items", fn(ctx: StepContext) {
      put(ctx.world, "cart", get_int(ctx.captures, 0) |> result.unwrap(0))
      Ok(succeed())
    })
    |> step("I add {int} more", fn(ctx: StepContext) {
      let current = get_or(ctx.world, "cart", 0)
      put(ctx.world, "cart", current + { get_int(ctx.captures, 0) |> result.unwrap(0) })
      Ok(succeed())
    })
    |> step("I should have {int} items", fn(ctx: StepContext) {
      get_or(ctx.world, "cart", 0)
      |> should |> be_equal(get_int(ctx.captures, 0) |> result.unwrap(0))
      |> or_fail_with("Cart count mismatch")
    })

  feature("Shopping Cart", steps, [
    scenario("Adding items", [
      given("I have 3 items"),
      when("I add 2 more"),
      then("I should have 5 items"),
    ]),
  ])
}
```

<sub>🧪 [Tested source](examples/shopping_cart/test/features/shopping_cart.gleam) · 📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

---

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a>.</sub>
</div>
