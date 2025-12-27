//// Discount application steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, get_int,
}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{succeed}
import dream_test/types.{type AssertionResult}
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
  |> steps.step("I apply a {int}% discount", step_apply_percent_discount)
  |> steps.step("I apply a ${float} discount", step_apply_fixed_discount)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_apply_percent_discount(
  context: StepContext,
) -> Result(AssertionResult, String) {
  let percent = get_int(context.captures, 0) |> result.unwrap(0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let discount = cart_types.PercentOff(int.to_float(percent))

  case pricing.apply_discount(the_cart, discount) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      Ok(succeed())
    }
    Error(_) -> {
      put(context.world, "last_error", "discount failed")
      Ok(succeed())
    }
  }
}

fn step_apply_fixed_discount(
  context: StepContext,
) -> Result(AssertionResult, String) {
  let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())
  let discount = cart_types.FixedAmount(amount)

  case pricing.apply_discount(the_cart, discount) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      Ok(succeed())
    }
    Error(_) -> {
      put(context.world, "last_error", "discount failed")
      Ok(succeed())
    }
  }
}
