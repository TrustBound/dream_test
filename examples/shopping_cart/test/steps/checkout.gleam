//// Checkout steps.

import dream_test/gherkin/steps.{type StepContext, type StepRegistry, Action}
import shopping_cart/checkout
import shopping_cart/types as cart_types
import steps/cart_world.{
  type CartWorld, type Checkout, CartWorld, CheckedOut, CheckoutFailed,
}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartWorld)) -> StepRegistry(CartWorld) {
  registry
  |> steps.when_("I checkout", Action(step_checkout))
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_checkout(
  world: CartWorld,
  _context: StepContext,
) -> Result(CartWorld, String) {
  Ok(
    CartWorld(
      ..world,
      checkout: checkout_outcome(checkout.checkout(world.cart)),
    ),
  )
}

fn checkout_outcome(
  result: Result(cart_types.CheckoutResult, cart_types.CartError),
) -> Checkout {
  case result {
    Ok(checkout_result) -> CheckedOut(checkout_result)
    Error(cart_types.CartEmpty) -> CheckoutFailed("cart is empty")
    Error(_) -> CheckoutFailed("checkout failed")
  }
}
