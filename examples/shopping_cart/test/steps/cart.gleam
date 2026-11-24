//// Cart setup and manipulation steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, get_string,
}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import shopping_cart/cart
import shopping_cart/products
import shopping_cart/types as cart_types
import steps/cart_state.{type CartState, CartState}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartState)) -> StepRegistry(CartState) {
  registry
  |> steps.given("I have an empty cart", step_empty_cart)
  |> steps.given("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.when("I update the {word} quantity to {int}", step_update_quantity)
  |> steps.when("I remove {word} from the cart", step_remove_product)
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_empty_cart(
  state: CartState,
  _context: StepContext,
) -> Result(CartState, String) {
  Ok(CartState(..state, cart: cart.new()))
}

fn step_add_product(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product_name <- result.try(get_string(context.captures, 1))
  use updated <- result.try(
    cart.add_item(state.cart, lookup_product(product_name), quantity)
    |> result.map_error(add_item_error_to_string),
  )
  Ok(CartState(..state, cart: updated))
}

fn step_try_add_product(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product_name <- result.try(get_string(context.captures, 1))
  case cart.add_item(state.cart, lookup_product(product_name), quantity) {
    Ok(updated) -> Ok(CartState(..state, cart: updated, last_error: None))
    Error(error) ->
      Ok(CartState(..state, last_error: Some(add_item_error_to_string(error))))
  }
}

fn add_item_error_to_string(error: cart_types.CartError) -> String {
  case error {
    cart_types.InvalidQuantity -> "invalid quantity"
    _ -> "add_item failed"
  }
}

fn step_update_quantity(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use product_name <- result.try(get_string(context.captures, 0))
  use quantity <- result.try(get_int(context.captures, 1))
  case
    cart.update_quantity(
      state.cart,
      normalize_product_id(product_name),
      quantity,
    )
  {
    Ok(updated) -> Ok(CartState(..state, cart: updated))
    Error(_) -> Ok(CartState(..state, last_error: Some("update failed")))
  }
}

fn step_remove_product(
  state: CartState,
  context: StepContext,
) -> Result(CartState, String) {
  use product_name <- result.try(get_string(context.captures, 0))
  case cart.remove_item(state.cart, normalize_product_id(product_name)) {
    Ok(updated) -> Ok(CartState(..state, cart: updated))
    Error(_) -> Ok(CartState(..state, last_error: Some("remove failed")))
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
