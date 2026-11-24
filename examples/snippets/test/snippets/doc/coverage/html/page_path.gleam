import dream_test/coverage/html

pub fn page_path_with_space() -> String {
  html.page_path("src/app/my cart.gleam")
  // -> "files/src/app/my~20cart.gleam.html"
}
