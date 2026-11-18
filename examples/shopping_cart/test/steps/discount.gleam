//// Discount application steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, get_int,
}
import gleam/int
import gleam/option.{Some}
import gleam/result
import shopping_cart/pricing
import shopping_cart/types as cart_types
import steps/cart_world.{type CartWorld, CartWorld}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartWorld)) -> StepRegistry(CartWorld) {
  registry
  |> steps.when("I apply a {int}% discount", step_apply_percent_discount)
  |> steps.when("I apply a ${float} discount", step_apply_fixed_discount)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_apply_percent_discount(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use percent <- result.try(get_int(context.captures, 0))
  Ok(apply_discount(world, cart_types.PercentOff(int.to_float(percent))))
}

fn step_apply_fixed_discount(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use amount <- result.try(get_float(context.captures, 0))
  Ok(apply_discount(world, cart_types.FixedAmount(amount)))
}

// ============================================================================
// Helpers
// ============================================================================

fn apply_discount(
  world: CartWorld,
  discount: cart_types.Discount,
) -> CartWorld {
  case pricing.apply_discount(world.cart, discount) {
    Ok(updated) -> CartWorld(..world, cart: updated)
    Error(_) -> CartWorld(..world, last_error: Some("discount failed"))
  }
}
