//// Pricing calculations: subtotals, discounts, and totals.

import gleam/dict
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import shopping_cart/types.{
  type Cart, type CartError, type CartItem, type Discount, BuyXGetYFree, Cart,
  DiscountNotApplicable, FixedAmount, PercentOff,
}

// ============================================================================
// Subtotal
// ============================================================================

/// Calculate the subtotal (before discounts)
pub fn subtotal(cart: Cart) -> Float {
  cart.items
  |> dict.values()
  |> do_subtotal(0.0)
}

fn do_subtotal(items: List(CartItem), acc: Float) -> Float {
  case items {
    [] -> acc
    [item, ..rest] -> {
      let item_total = item.product.price *. int.to_float(item.quantity)
      do_subtotal(rest, acc +. item_total)
    }
  }
}

// ============================================================================
// Discounts
// ============================================================================

/// Apply a discount to the cart
pub fn apply_discount(cart: Cart, discount: Discount) -> Result(Cart, CartError) {
  case discount {
    BuyXGetYFree(_, _, product_id) -> {
      case dict.has_key(cart.items, product_id) {
        False -> Error(DiscountNotApplicable)
        True -> Ok(Cart(..cart, discount: Some(discount)))
      }
    }
    _ -> Ok(Cart(..cart, discount: Some(discount)))
  }
}

/// Remove any applied discount
pub fn remove_discount(cart: Cart) -> Cart {
  Cart(..cart, discount: None)
}

/// Calculate the discount amount
pub fn discount_amount(cart: Cart) -> Float {
  let sub = subtotal(cart)
  case cart.discount {
    None -> 0.0
    Some(PercentOff(percent)) -> sub *. { percent /. 100.0 }
    Some(FixedAmount(amount)) -> float.min(amount, sub)
    Some(BuyXGetYFree(buy, get_free, product_id)) -> {
      case dict.get(cart.items, product_id) {
        Error(_) -> 0.0
        Ok(item) -> {
          let sets = item.quantity / { buy + get_free }
          let free_items = sets * get_free
          int.to_float(free_items) *. item.product.price
        }
      }
    }
  }
}

// ============================================================================
// Total
// ============================================================================

/// Calculate the final total (after discounts)
pub fn total(cart: Cart) -> Float {
  subtotal(cart) -. discount_amount(cart)
}
