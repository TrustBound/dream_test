# Shopping Cart — Gherkin BDD Example

This example demonstrates **Cucumber/Gherkin-style BDD testing** with Dream Test.

## Project Structure

```text
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
│       ├── shopping_cart.gleam     # Inline DSL feature definition
│       └── shopping_cart_file.gleam # Loads `features/*.feature` into a TestSuite
└── README.md
```

## Two Approaches

This example project runs **both** the `.feature` file(s) in `features/` and the
inline DSL suite.

### 1. Gherkin Feature Files

Write features in standard `.feature` files:

#### The feature file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/shopping_cart/features/shopping_cart.feature#L1-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
@shopping @e2e
Feature: Shopping Cart
  As a customer
  I want to manage items in my shopping cart
  So that I can purchase products I need

  Background:
    Given I have an empty cart

  @happy-path
  Scenario: Adding a single item to the cart
    When I add 2 apples to the cart
    Then the cart should contain 2 items
    And the subtotal should be $3.00
```

### 2. Inline DSL

Define features directly in Gleam:

#### The inline feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/shopping_cart/test/features/shopping_cart.gleam#L25-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  feature_with_background("Shopping Cart (inline)", registry, bg, [
    scenario("Adding a single item to the cart", [
      when("I add 2 apples to the cart"),
      then("the cart should contain 2 items"),
      and("the subtotal should be $3.00"),
    ])
      |> with_tags(["happy-path"]),
```

Both approaches share the same step definitions!

## Step Definitions

Steps are organized by domain concern in `test/steps/`:

Each scenario starts from `cart_state.initial()` and passes one `CartState` value from step to step. A `given` or `when` step returns a new `CartState`. A `then` step reads it.

### The scenario state <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/shopping_cart/test/steps/cart_state.gleam#L8-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type CartState {
  CartState(
    /// The cart that the steps change
    cart: cart_types.Cart,
    /// What happened at checkout
    checkout: Checkout,
    /// The error of the last cart operation that failed, if any
    last_error: Option(String),
  )
}

/// What happened at checkout.
pub type Checkout {
  NotCheckedOut
  CheckedOut(result: cart_types.CheckoutResult)
  CheckoutFailed(reason: String)
}
```

### Cart step registration <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/shopping_cart/test/steps/cart.gleam#L18-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn register(registry: StepRegistry(CartState)) -> StepRegistry(CartState) {
  registry
  |> steps.given("I have an empty cart", step_empty_cart)
  |> steps.given("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.when("I update the {word} quantity to {int}", step_update_quantity)
  |> steps.when("I remove {word} from the cart", step_remove_product)
}
```

### Cucumber Expression Placeholders

| Placeholder | Matches     | Example       |
| ----------- | ----------- | ------------- |
| `{int}`     | Integers    | `5`, `42`     |
| `{float}`   | Decimals    | `3.14`, `0.5` |
| `{string}`  | Quoted text | `"hello"`     |
| `{word}`    | Single word | `apple`       |

## Running

```bash
cd examples/shopping_cart
make test
```

## Output

```text
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
