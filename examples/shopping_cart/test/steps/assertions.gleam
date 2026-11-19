//// Assertion/verification steps (Then steps).

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, get_int, get_string,
}
import dream_test/matchers.{be_equal, be_true, or_fail_with, should, succeed}
import dream_test/types.{type AssertionResult}
import gleam/float
import gleam/int
import gleam/option.{Some}
import gleam/result
import shopping_cart/cart
import shopping_cart/pricing
import steps/cart_world.{
  type CartWorld, CheckedOut, CheckoutFailed, NotCheckedOut,
}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartWorld)) -> StepRegistry(CartWorld) {
  registry
  |> steps.then("the cart should contain {int} items", step_verify_item_count)
  |> steps.then("the subtotal should be ${float}", step_verify_subtotal)
  |> steps.then("the discount should be ${float}", step_verify_discount)
  |> steps.then("the total should be ${float}", step_verify_total)
  |> steps.then("the checkout should succeed", step_verify_checkout_success)
  |> steps.then(
    "the checkout should fail with {string}",
    step_verify_checkout_failure,
  )
  |> steps.then("the order total should be ${float}", step_verify_order_total)
  |> steps.then(
    "the operation should fail with {string}",
    step_verify_operation_failure,
  )
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_verify_item_count(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.item_count(world.cart)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart should contain " <> int.to_string(expected) <> " items")
}

fn step_verify_subtotal(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_float(context.captures, 0))
  floats_equal(pricing.subtotal(world.cart), expected)
  |> should
  |> be_true()
  |> or_fail_with("Subtotal should be $" <> float.to_string(expected))
}

fn step_verify_discount(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_float(context.captures, 0))
  floats_equal(pricing.discount_amount(world.cart), expected)
  |> should
  |> be_true()
  |> or_fail_with("Discount should be $" <> float.to_string(expected))
}

fn step_verify_total(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_float(context.captures, 0))
  floats_equal(pricing.total(world.cart), expected)
  |> should
  |> be_true()
  |> or_fail_with("Total should be $" <> float.to_string(expected))
}

fn step_verify_checkout_success(
  world: CartWorld,
  _context: StepContext,
) -> Result(AssertionResult, String) {
  case world.checkout {
    CheckedOut(_) -> Ok(succeed())
    NotCheckedOut -> Error("No checkout result found")
    CheckoutFailed(reason) -> Error("Checkout failed: " <> reason)
  }
}

fn step_verify_checkout_failure(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected_error <- result.try(get_string(context.captures, 0))
  world.checkout
  |> should
  |> be_equal(CheckoutFailed(expected_error))
  |> or_fail_with("Checkout should fail with: " <> expected_error)
}

fn step_verify_order_total(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_float(context.captures, 0))
  case world.checkout {
    CheckedOut(the_checkout) ->
      floats_equal(the_checkout.total, expected)
      |> should
      |> be_true()
      |> or_fail_with("Order total should be $" <> float.to_string(expected))
    NotCheckedOut -> Error("No checkout result found")
    CheckoutFailed(reason) -> Error("Checkout failed: " <> reason)
  }
}

fn step_verify_operation_failure(
  world: CartWorld,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected_error <- result.try(get_string(context.captures, 0))
  world.last_error
  |> should
  |> be_equal(Some(expected_error))
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
