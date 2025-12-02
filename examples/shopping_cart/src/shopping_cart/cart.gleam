//// Cart lifecycle and item operations.

import gleam/dict
import gleam/option.{None, Some}
import shopping_cart/types.{
  type Cart, type CartError, type CartItem, type Product, Cart, CartItem,
  InvalidQuantity, ProductNotFound,
}

// ============================================================================
// Cart Lifecycle
// ============================================================================

/// Create a new empty cart
pub fn new() -> Cart {
  Cart(items: dict.new(), discount: None)
}

/// Check if the cart is empty
pub fn is_empty(cart: Cart) -> Bool {
  dict.is_empty(cart.items)
}

// ============================================================================
// Item Operations
// ============================================================================

/// Add a product to the cart with the specified quantity
pub fn add_item(
  cart: Cart,
  product: Product,
  quantity: Int,
) -> Result(Cart, CartError) {
  case quantity > 0 {
    False -> Error(InvalidQuantity)
    True -> {
      let new_items = case dict.get(cart.items, product.id) {
        Ok(existing) -> {
          let updated = CartItem(product, existing.quantity + quantity)
          dict.insert(cart.items, product.id, updated)
        }
        Error(_) -> {
          dict.insert(cart.items, product.id, CartItem(product, quantity))
        }
      }
      Ok(Cart(..cart, items: new_items))
    }
  }
}

/// Remove a product from the cart entirely
pub fn remove_item(cart: Cart, product_id: String) -> Result(Cart, CartError) {
  case dict.has_key(cart.items, product_id) {
    False -> Error(ProductNotFound)
    True -> Ok(Cart(..cart, items: dict.delete(cart.items, product_id)))
  }
}

/// Update the quantity of a product in the cart
pub fn update_quantity(
  cart: Cart,
  product_id: String,
  quantity: Int,
) -> Result(Cart, CartError) {
  case quantity {
    0 -> remove_item(cart, product_id)
    q if q < 0 -> Error(InvalidQuantity)
    _ -> {
      case dict.get(cart.items, product_id) {
        Error(_) -> Error(ProductNotFound)
        Ok(item) -> {
          let updated = CartItem(..item, quantity: quantity)
          Ok(Cart(..cart, items: dict.insert(cart.items, product_id, updated)))
        }
      }
    }
  }
}

/// Get a specific item from the cart
pub fn get_item(cart: Cart, product_id: String) -> option.Option(CartItem) {
  case dict.get(cart.items, product_id) {
    Ok(item) -> Some(item)
    Error(_) -> None
  }
}

/// Get all items in the cart
pub fn items(cart: Cart) -> List(CartItem) {
  dict.values(cart.items)
}

/// Get the total number of items in the cart (sum of quantities)
pub fn item_count(cart: Cart) -> Int {
  cart.items
  |> dict.values()
  |> do_item_count(0)
}

fn do_item_count(items: List(CartItem), acc: Int) -> Int {
  case items {
    [] -> acc
    [item, ..rest] -> do_item_count(rest, acc + item.quantity)
  }
}
