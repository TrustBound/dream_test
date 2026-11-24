//// A shopping cart, for the coverage exclusion snippet. Coverage measures
//// this file.

/// The total of the item prices in a cart.
pub fn total(prices: List(Int)) -> Int {
  case prices {
    [] -> 0
    [price, ..rest] -> price + total(rest)
  }
}
