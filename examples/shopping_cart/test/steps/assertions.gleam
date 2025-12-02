//// Assertion/verification steps (Then steps).

import dream_test/assertions/should.{be_true, equal, or_fail_with, should}
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, get_int, get_string,
}
import dream_test/gherkin/world.{get, get_or}
import dream_test/types.{type AssertionResult}
import gleam/float
import gleam/int
import gleam/result
import shopping_cart/cart
import shopping_cart/pricing
import shopping_cart/types as cart_types

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> steps.step("the cart should contain {int} items", step_verify_item_count)
  |> steps.step("the subtotal should be ${float}", step_verify_subtotal)
  |> steps.step("the discount should be ${float}", step_verify_discount)
  |> steps.step("the total should be ${float}", step_verify_total)
  |> steps.step("the checkout should succeed", step_verify_checkout_success)
  |> steps.step(
    "the checkout should fail with {string}",
    step_verify_checkout_failure,
  )
  |> steps.step("the order total should be ${float}", step_verify_order_total)
  |> steps.step(
    "the operation should fail with {string}",
    step_verify_operation_failure,
  )
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_verify_item_count(context: StepContext) -> AssertionResult {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let actual = cart.item_count(the_cart)

  actual
  |> should()
  |> equal(expected)
  |> or_fail_with("Cart should contain " <> int.to_string(expected) <> " items")
}

fn step_verify_subtotal(context: StepContext) -> AssertionResult {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let actual = pricing.subtotal(the_cart)

  floats_equal(actual, expected)
  |> should()
  |> be_true()
  |> or_fail_with("Subtotal should be $" <> float.to_string(expected))
}

fn step_verify_discount(context: StepContext) -> AssertionResult {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let actual = pricing.discount_amount(the_cart)

  floats_equal(actual, expected)
  |> should()
  |> be_true()
  |> or_fail_with("Discount should be $" <> float.to_string(expected))
}

fn step_verify_total(context: StepContext) -> AssertionResult {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let actual = pricing.total(the_cart)

  floats_equal(actual, expected)
  |> should()
  |> be_true()
  |> or_fail_with("Total should be $" <> float.to_string(expected))
}

fn step_verify_checkout_success(context: StepContext) -> AssertionResult {
  let success: Bool = get_or(context.world, "checkout_success", False)

  success
  |> should()
  |> be_true()
  |> or_fail_with("Checkout should succeed")
}

fn step_verify_checkout_failure(context: StepContext) -> AssertionResult {
  let expected_error = get_string(context.captures, 0) |> result.unwrap("")
  let success: Bool = get_or(context.world, "checkout_success", True)
  let actual_error: String = get_or(context.world, "checkout_error", "")

  case success {
    True -> {
      False
      |> should()
      |> be_true()
      |> or_fail_with("Checkout should have failed")
    }
    False -> {
      actual_error
      |> should()
      |> equal(expected_error)
      |> or_fail_with("Error should be: " <> expected_error)
    }
  }
}

fn step_verify_order_total(context: StepContext) -> AssertionResult {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)

  case get(context.world, "checkout_result") {
    Ok(checkout_result) -> {
      let the_checkout: cart_types.CheckoutResult = checkout_result
      floats_equal(the_checkout.total, expected)
      |> should()
      |> be_true()
      |> or_fail_with("Order total should be $" <> float.to_string(expected))
    }
    Error(_) -> {
      False
      |> should()
      |> be_true()
      |> or_fail_with("No checkout result found")
    }
  }
}

fn step_verify_operation_failure(context: StepContext) -> AssertionResult {
  let expected_error = get_string(context.captures, 0) |> result.unwrap("")
  let actual_error: String = get_or(context.world, "last_error", "")

  actual_error
  |> should()
  |> equal(expected_error)
  |> or_fail_with("Operation should fail with: " <> expected_error)
}

// ============================================================================
// Helpers
// ============================================================================

fn floats_equal(a: Float, b: Float) -> Bool {
  let diff = case a -. b {
    d if d <. 0.0 -> 0.0 -. d
    d -> d
  }
  diff <. 0.01
}
