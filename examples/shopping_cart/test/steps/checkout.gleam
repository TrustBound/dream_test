//// Checkout steps.

import dream_test/gherkin/steps.{type StepContext, type StepRegistry}
import shopping_cart/checkout
import shopping_cart/types as cart_types
import steps/cart_state.{
  type CartState, type Checkout, CartState, CheckedOut, CheckoutFailed,
}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartState)) -> StepRegistry(CartState) {
  registry
  |> steps.when("I checkout", step_checkout)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_checkout(
  state: CartState,
  _context: StepContext,
) -> Result(CartState, String) {
  Ok(
    CartState(
      ..state,
      checkout: checkout_outcome(checkout.checkout(state.cart)),
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
