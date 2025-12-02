# Dream Test 1.1.0 Release Notes

**Release Date:** December 2, 2025

Dream Test 1.1.0 introduces full Gherkin/Cucumber-style BDD testing support, bringing behavior-driven development to Gleam with typed step definitions and seamless integration with the existing test runner.

## What's New

### 🥒 Gherkin/Cucumber BDD Support

Write behavior-driven tests using familiar Given/When/Then syntax:

**Inline DSL:**

```gleam
import dream_test/gherkin/feature.{feature, scenario, given, when, then}
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}

pub fn tests() {
  let steps =
    new_registry()
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
  Scenario: Adding items to cart ✓

1 scenario (1 passed)
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
  AssertionOk
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

### Additional Features

- **Background steps** for shared setup across scenarios
- **Tag support** (`@smoke`, `@slow`) for filtering scenarios
- **Scenario Outline** with Examples table expansion
- **Data tables** and **doc strings** in steps
- **Gherkin-style reporter** with scenario-level output

## New Dependencies

- `gleam_regexp >= 1.0.0` — for step pattern tokenization
- `dream_ets >= 1.0.0` — for World state management

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
