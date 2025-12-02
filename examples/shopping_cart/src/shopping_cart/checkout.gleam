//// Checkout operations.

import shopping_cart/cart as cart_ops
import shopping_cart/pricing
import shopping_cart/types.{
  type Cart, type CartError, type CheckoutResult, CartEmpty, CheckoutResult,
}

/// Attempt to checkout the cart
pub fn checkout(cart: Cart) -> Result(CheckoutResult, CartError) {
  case cart_ops.is_empty(cart) {
    True -> Error(CartEmpty)
    False -> {
      Ok(CheckoutResult(
        items: cart_ops.items(cart),
        subtotal: pricing.subtotal(cart),
        discount: pricing.discount_amount(cart),
        total: pricing.total(cart),
      ))
    }
  }
}
