import dream_test/coverage/html

pub fn page_of_cart_file() -> String {
  html.page_path("src/app/cart.gleam")
  // -> "files/src/app/cart.gleam.html"
}
