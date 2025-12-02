//// Cart setup and manipulation steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, get_string,
}
import dream_test/gherkin/world.{get_or, put}
import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/result
import gleam/string
import shopping_cart/cart
import shopping_cart/products
import shopping_cart/types as cart_types

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> steps.step("I have an empty cart", step_empty_cart)
  |> steps.step("I add {int} {word} to the cart", step_add_product)
  |> steps.step("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.step("I update the {word} quantity to {int}", step_update_quantity)
  |> steps.step("I remove {word} from the cart", step_remove_product)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_empty_cart(context: StepContext) -> AssertionResult {
  put(context.world, "cart", cart.new())
  AssertionOk
}

fn step_add_product(context: StepContext) -> AssertionResult {
  let quantity = get_int(context.captures, 0) |> result.unwrap(0)
  let product =
    get_string(context.captures, 1) |> result.unwrap("") |> lookup_product()
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case cart.add_item(the_cart, product, quantity) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      AssertionOk
    }
    Error(_) -> {
      put(context.world, "last_error", "add_item failed")
      AssertionOk
    }
  }
}

fn step_try_add_product(context: StepContext) -> AssertionResult {
  let quantity = get_int(context.captures, 0) |> result.unwrap(0)
  let product =
    get_string(context.captures, 1) |> result.unwrap("") |> lookup_product()
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case cart.add_item(the_cart, product, quantity) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      put(context.world, "last_error", "")
      AssertionOk
    }
    Error(cart_types.InvalidQuantity) -> {
      put(context.world, "last_error", "invalid quantity")
      AssertionOk
    }
    Error(_) -> {
      put(context.world, "last_error", "unknown error")
      AssertionOk
    }
  }
}

fn step_update_quantity(context: StepContext) -> AssertionResult {
  let product_name = get_string(context.captures, 0) |> result.unwrap("")
  let quantity = get_int(context.captures, 1) |> result.unwrap(0)
  let product_id = normalize_product_id(product_name)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case cart.update_quantity(the_cart, product_id, quantity) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      AssertionOk
    }
    Error(_) -> {
      put(context.world, "last_error", "update failed")
      AssertionOk
    }
  }
}

fn step_remove_product(context: StepContext) -> AssertionResult {
  let product_name = get_string(context.captures, 0) |> result.unwrap("")
  let product_id = normalize_product_id(product_name)
  let the_cart: cart_types.Cart = get_or(context.world, "cart", cart.new())

  case cart.remove_item(the_cart, product_id) {
    Ok(updated) -> {
      put(context.world, "cart", updated)
      AssertionOk
    }
    Error(_) -> {
      put(context.world, "last_error", "remove failed")
      AssertionOk
    }
  }
}

// ============================================================================
// Helpers
// ============================================================================

fn lookup_product(name: String) -> cart_types.Product {
  case string.lowercase(name) {
    "apple" | "apples" -> products.apple()
    "banana" | "bananas" -> products.banana()
    "orange" | "oranges" -> products.orange()
    "milk" -> products.milk()
    "bread" -> products.bread()
    _ -> cart_types.Product(id: name, name: name, price: 1.0)
  }
}

fn normalize_product_id(name: String) -> String {
  case string.lowercase(name) {
    "apples" -> "apple"
    "bananas" -> "banana"
    "oranges" -> "orange"
    other -> other
  }
}
