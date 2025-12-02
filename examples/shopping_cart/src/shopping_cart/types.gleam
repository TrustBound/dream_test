//// Core types for the shopping cart domain.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// A product that can be added to the cart
pub type Product {
  Product(id: String, name: String, price: Float)
}

/// An item in the cart (product + quantity)
pub type CartItem {
  CartItem(product: Product, quantity: Int)
}

/// A discount that can be applied to the cart
pub type Discount {
  PercentOff(percent: Float)
  FixedAmount(amount: Float)
  BuyXGetYFree(buy: Int, get_free: Int, product_id: String)
}

/// The shopping cart itself
pub type Cart {
  Cart(items: Dict(String, CartItem), discount: Option(Discount))
}

/// Errors that can occur during cart operations
pub type CartError {
  ProductNotFound
  InvalidQuantity
  CartEmpty
  InsufficientStock
  DiscountNotApplicable
}

/// Checkout result containing the final order details
pub type CheckoutResult {
  CheckoutResult(
    items: List(CartItem),
    subtotal: Float,
    discount: Float,
    total: Float,
  )
}
