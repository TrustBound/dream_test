# Shopping Cart — Gherkin BDD Example

This example demonstrates **Cucumber/Gherkin-style BDD testing** with Dream Test.

## Project Structure

```
shopping_cart/
├── src/shopping_cart/
│   ├── types.gleam             # Core domain types
│   ├── cart.gleam              # Cart lifecycle and item operations
│   ├── pricing.gleam           # Subtotals, discounts, and totals
│   ├── checkout.gleam          # Checkout operations
│   └── products.gleam          # Sample product catalog
├── features/
│   └── shopping_cart.feature   # Gherkin feature file
├── test/
│   ├── shopping_cart_test.gleam    # Test entry point
│   ├── steps/
│   │   ├── cart.gleam              # Cart manipulation steps
│   │   ├── discount.gleam          # Discount application steps
│   │   ├── checkout.gleam          # Checkout steps
│   │   └── assertions.gleam        # Verification steps (Then)
│   └── features/
│       └── shopping_cart.gleam     # Inline feature definition
└── README.md
```

## Two Approaches

### 1. Gherkin Feature Files

Write features in standard `.feature` files:

```gherkin
# features/shopping_cart.feature
Feature: Shopping Cart

  Background:
    Given I have an empty cart

  Scenario: Adding items to cart
    When I add 2 apples to the cart
    Then the cart should contain 2 items
    And the subtotal should be $3.00
```

### 2. Inline DSL

Define features directly in Gleam:

```gleam
feature_with_background("Shopping Cart", registry, bg, [
  scenario("Adding items to cart", [
    when("I add 2 apples to the cart"),
    then("the cart should contain 2 items"),
    and("the subtotal should be $3.00"),
  ]),
])
```

Both approaches share the same step definitions!

## Step Definitions

Steps are organized by domain concern in `test/steps/`:

```gleam
// test/steps/cart.gleam
pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> steps.step("I have an empty cart", step_empty_cart)
  |> steps.step("I add {int} {word} to the cart", step_add_product)
}
```

### Cucumber Expression Placeholders

| Placeholder | Matches | Example |
|-------------|---------|---------|
| `{int}` | Integers | `5`, `42` |
| `{float}` | Decimals | `3.14`, `0.5` |
| `{string}` | Quoted text | `"hello"` |
| `{word}` | Single word | `apple` |

## Running

```bash
cd examples/shopping_cart
gleam test
```

## Output

```
Shopping Cart — Gherkin BDD Example
====================================

Shopping Cart
  ✓ Adding a single item to the cart
  ✓ Adding multiple different items
  ✓ Updating item quantity
  ✓ Removing an item from the cart
  ✓ Applying a percentage discount
  ✓ Successful checkout
  ✓ Cannot checkout an empty cart
  ✓ Cannot add zero items

Summary: 8 run, 0 failed, 8 passed
```
