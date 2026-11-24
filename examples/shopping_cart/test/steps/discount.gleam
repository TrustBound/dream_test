//// Discount application steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, get_int,
}
import gleam/int
import gleam/option.{Some}
import gleam/result
import shopping_cart/pricing
import shopping_cart/types as cart_types
import steps/cart_state.{type CartState, CartState}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartState)) -> StepRegistry(CartState) {
  registry
  |> steps.when("I apply a {int}% discount", step_apply_percent_discount)
  |> steps.when("I apply a ${float} discount", step_apply_fixed_discount)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_apply_percent_discount(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use percent <- result.try(get_int(context.captures, 0))
  Ok(apply_discount(state, cart_types.PercentOff(int.to_float(percent))))
}

fn step_apply_fixed_discount(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use amount <- result.try(get_float(context.captures, 0))
  Ok(apply_discount(state, cart_types.FixedAmount(amount)))
}

// ============================================================================
// Helpers
// ============================================================================

fn apply_discount(
  state: CartState,
  discount: cart_types.Discount,
) -> CartState {
  case pricing.apply_discount(state.cart, discount) {
    Ok(updated) -> CartState(..state, cart: updated)
    Error(_) -> CartState(..state, last_error: Some("discount failed"))
  }
}
