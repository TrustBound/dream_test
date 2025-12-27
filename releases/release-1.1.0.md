# Dream Test 1.1.0 Release Notes

**Release Date:** December 2, 2025

Dream Test 1.1.0 introduces full Gherkin/Cucumber-style BDD testing support, test tagging and filtering, and per-test timing—bringing behavior-driven development to Gleam with typed step definitions and seamless integration with the existing test runner.

## What's New

### 🥒 Gherkin/Cucumber BDD Support

Write behavior-driven tests using familiar Given/When/Then syntax:

**Inline DSL:**

```gleam
import dream_test/gherkin/feature.{feature, scenario, given, when, then}
import dream_test/gherkin/steps.{type StepContext, get_int, step}

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
```

**Output:**

```
Feature: Shopping Cart
  Scenario: Adding items to cart ✓ (3ms)

Summary: 1 run, 0 failed, 1 passed in 3ms
```

### 📄 .feature File Support

Parse standard Gherkin `.feature` files:

```gherkin
@shopping
Feature: Shopping Cart
  As a customer I want to add items to my cart

  Background:
    Given I have an empty cart

  @smoke
  Scenario: Adding items
    When I add 3 items
    Then the cart should have 3 items
```

```gleam
let assert Ok(feature) = parser.parse_file("test/cart.feature")
let config = FeatureConfig(feature: feature, step_registry: steps)
to_test_suite("cart_test", config)
```

### 🎯 Typed Step Placeholders

Capture values from step text with type-safe placeholders:

| Placeholder | Matches              | Example         |
| ----------- | -------------------- | --------------- |
| `{int}`     | Integers             | `42`, `-5`      |
| `{float}`   | Decimals             | `3.14`, `-0.5`  |
| `{string}`  | Quoted strings       | `"hello world"` |
| `{word}`    | Single unquoted word | `alice`         |

Placeholders work with prefixes and suffixes—`${float}` matches `$19.99` and captures `19.99`:

```gleam
registry
|> step("I have a balance of ${float}", step_have_balance)
|> step("the total should be ${float}", step_check_total)
```

### 🌍 World State Management

ETS-backed mutable state shared between steps within a scenario:

```gleam
fn step_add_item(context: StepContext) -> AssertionResult {
  let current = get_or(context.world, "cart_count", 0)
  put(context.world, "cart_count", current + 1)
  succeed()
}
```

### 📁 Feature Discovery

Load multiple `.feature` files with glob patterns:

```gleam
import dream_test/gherkin/discover

discover.features("test/**/*.feature")
|> discover.with_registry(steps)
|> discover.to_suite("my_features")
```

### ⏱️ Per-Test Timing

See exactly how long each test takes with human-readable duration formatting:

```
Calculator
  ✓ adds two numbers
  ✓ handles division (1ms)
  ✓ returns error for division by zero

Summary: 3 run, 0 failed, 3 passed in 2ms
```

Duration scales automatically: `42ms` → `1.5s` → `2m 30s` → `1h 15m`

### ✅ `succeed()` Function

A new `succeed()` function provides an explicit way to mark success in conditional branches—the natural counterpart to `fail_with()`:

```gleam
import dream_test/assertions/should.{fail_with, succeed}

case result {
  Ok(_) -> succeed()
  Error(_) -> fail_with("Should have succeeded")
}
```

Use `succeed()` instead of importing `AssertionOk` directly for cleaner, more idiomatic test code.

### 🏷️ Test Tagging and Filtering

Tag tests for selective execution during development or CI:

```gleam
import dream_test/unit.{describe, it, with_tags}

describe("Calculator", [
  it("adds numbers", fn() { ... })
    |> with_tags(["unit", "fast"]),
  it("complex calculation", fn() { ... })
    |> with_tags(["integration", "slow"]),
])
```

Filter which tests run using `RunnerConfig.test_filter`:

```gleam
import dream_test/runner.{RunnerConfig, run_all_with_config}
import gleam/list

let config = RunnerConfig(
  max_concurrency: 4,
  default_timeout_ms: 5000,
  test_filter: Some(fn(c) { list.contains(c.tags, "unit") }),
)

test_cases |> run_all_with_config(config)
```

The filter is a predicate function receiving `SingleTestConfig`, giving you full control. Filter by tags, test name, kind, or any combination—you decide how to populate the filter (env vars, CLI args, hardcoded for debugging).

Tagging works for both unit tests (`dream_test/unit.with_tags`) and Gherkin scenarios (`dream_test/gherkin/feature.with_tags`), with tags unified at the `SingleTestConfig` level.

### 🔧 Custom Matchers Documentation

Create your own matchers that work seamlessly with the assertion chain. The README now includes a guide for writing custom matchers using `MatchResult(a)`:

```gleam
pub fn be_even(result: MatchResult(Int)) -> MatchResult(Int) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(value) -> case value % 2 == 0 {
      True -> MatchOk(value)
      False -> MatchFailed(AssertionFailure(
        operator: "be_even",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(value),
          description: "expected an even number",
        )),
      ))
    }
  }
}

// Use it like any built-in matcher
4 |> should |> be_even() |> or_fail_with("Should be even")
```

### 📊 JSON Reporter

Output test results as JSON for CI/CD integration, test aggregation, or tooling:

```gleam
import dream_test/reporters/json
import dream_test/reporters/bdd.{report}

pub fn main() {
  to_test_cases("my_test", tests())
  |> run_all()
  |> report(io.print)           // Human-readable to stdout
  |> json.report(write_to_file) // JSON to file
  |> exit_on_failure()
}
```

JSON output includes:

- Schema version for forward compatibility
- Timestamp and total duration
- System info (OS, OTP version, Gleam version)
- Summary counts (passed, failed, skipped, etc.)
- Per-test details with name, full path, status, duration, tags, and failures
- Detailed failure payloads with expected/actual values

### Additional Features

- **Background steps** for shared setup across scenarios
- **Tag support** (`@smoke`, `@slow`) for filtering scenarios
- **Scenario Outline** with Examples table expansion
- **Data tables** and **doc strings** in steps
- **Gherkin-style reporter** with scenario-level output

## New Dependencies

- `gleam_regexp >= 1.0.0` — for step pattern tokenization
- `gleam_json >= 2.0.0` — for JSON reporter

## Upgrading

Update your dependencies to 1.1.0:

```toml
[dev-dependencies]
dream_test = "~> 1.1"
```

Then run:

```bash
gleam deps download
```

## No Breaking Changes

This release is fully backward compatible. All existing tests continue to work without modification. Gherkin support is entirely additive.

## Examples

See the new [examples/shopping_cart](https://github.com/TrustBound/dream_test/tree/main/examples/shopping_cart) for a complete Gherkin BDD example with:

- Inline DSL features
- `.feature` file parsing
- Step definitions organized by domain
- Application code under test

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)
- [Gherkin README Section](https://github.com/TrustBound/dream_test#gherkin--bdd-testing)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)
