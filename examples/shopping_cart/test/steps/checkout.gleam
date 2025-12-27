//// Checkout steps.

import dream_test/gherkin/steps.{type StepContext, type StepRegistry}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{succeed}
import dream_test/types.{type AssertionResult}
import shopping_cart/cart
import shopping_cart/checkout
import shopping_cart/types as cart_types

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> steps.step("I checkout", step_checkout)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_checkout(context: StepContext) -> Result(AssertionResult, String) {
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case checkout.checkout(the_cart) {
    Ok(checkout_result) -> {
      put(context.world, "checkout_result", checkout_result)
      put(context.world, "checkout_success", True)
      Ok(succeed())
    }
    Error(cart_types.CartEmpty) -> {
      put(context.world, "checkout_success", False)
      put(context.world, "checkout_error", "cart is empty")
      Ok(succeed())
    }
    Error(_) -> {
      put(context.world, "checkout_success", False)
      put(context.world, "checkout_error", "checkout failed")
      Ok(succeed())
    }
  }
}
