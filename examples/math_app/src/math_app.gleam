import gleam/int

/// A tiny mock application module used to demonstrate dream_test usage.

pub fn add(a: Int, b: Int) -> Int {
  a + b
}

pub fn parse_int(text: String) -> Result(Int, String) {
  case int.parse(text) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Could not parse integer from string: " <> text)
  }
}
