//// Cart setup and manipulation steps.

import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, Action, get_int, get_string,
}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import shopping_cart/cart
import shopping_cart/products
import shopping_cart/types as cart_types
import steps/cart_world.{type CartWorld, CartWorld}

// ============================================================================
// Step Registration
// ============================================================================

pub fn register(registry: StepRegistry(CartWorld)) -> StepRegistry(CartWorld) {
  registry
  |> steps.given("I have an empty cart", Action(step_empty_cart))
  |> steps.given("I add {int} {word} to the cart", Action(step_add_product))
  |> steps.when_("I add {int} {word} to the cart", Action(step_add_product))
  |> steps.when_(
    "I try to add {int} {word} to the cart",
    Action(step_try_add_product),
  )
  |> steps.when_(
    "I update the {word} quantity to {int}",
    Action(step_update_quantity),
  )
  |> steps.when_("I remove {word} from the cart", Action(step_remove_product))
}

// ============================================================================
// Step Implementations
// ============================================================================

fn step_empty_cart(
  world: CartWorld,
  _context: StepContext,
) -> Result(CartWorld, String) {
  Ok(CartWorld(..world, cart: cart.new()))
}

fn step_add_product(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product_name <- result.try(get_string(context.captures, 1))
  use updated <- result.try(
    cart.add_item(world.cart, lookup_product(product_name), quantity)
    |> result.map_error(add_item_error_to_string),
  )
  Ok(CartWorld(..world, cart: updated))
}

fn step_try_add_product(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product_name <- result.try(get_string(context.captures, 1))
  case cart.add_item(world.cart, lookup_product(product_name), quantity) {
    Ok(updated) -> Ok(CartWorld(..world, cart: updated, last_error: None))
    Error(error) ->
      Ok(CartWorld(..world, last_error: Some(add_item_error_to_string(error))))
  }
}

fn add_item_error_to_string(error: cart_types.CartError) -> String {
  case error {
    cart_types.InvalidQuantity -> "invalid quantity"
    _ -> "add_item failed"
  }
}

fn step_update_quantity(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use product_name <- result.try(get_string(context.captures, 0))
  use quantity <- result.try(get_int(context.captures, 1))
  case
    cart.update_quantity(
      world.cart,
      normalize_product_id(product_name),
      quantity,
    )
  {
    Ok(updated) -> Ok(CartWorld(..world, cart: updated))
    Error(_) -> Ok(CartWorld(..world, last_error: Some("update failed")))
  }
}

fn step_remove_product(
  world: CartWorld,
  context: StepContext,
) -> Result(CartWorld, String) {
  use product_name <- result.try(get_string(context.captures, 0))
  case cart.remove_item(world.cart, normalize_product_id(product_name)) {
    Ok(updated) -> Ok(CartWorld(..world, cart: updated))
    Error(_) -> Ok(CartWorld(..world, last_error: Some("remove failed")))
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
