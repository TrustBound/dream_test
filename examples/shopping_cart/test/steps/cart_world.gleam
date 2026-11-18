//// The state that the shopping cart steps pass from one step to the next.

import gleam/option.{type Option, None}
import shopping_cart/cart
import shopping_cart/types as cart_types

/// The state of one scenario.
pub type CartWorld {
  CartWorld(
    /// The cart that the steps change
    cart: cart_types.Cart,
    /// What happened at checkout
    checkout: Checkout,
    /// The error of the last cart operation that failed, if any
    last_error: Option(String),
  )
}

/// What happened at checkout.
pub type Checkout {
  NotCheckedOut
  CheckedOut(result: cart_types.CheckoutResult)
  CheckoutFailed(reason: String)
}

/// The state that each scenario starts from: an empty cart.
pub fn initial() -> CartWorld {
  CartWorld(cart: cart.new(), checkout: NotCheckedOut, last_error: None)
}
