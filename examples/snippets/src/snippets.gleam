//// Simple calculator for README examples.

/// Add two numbers
pub fn add(a: Int, b: Int) -> Int {
  a + b
}

/// Divide two numbers, returning an error for division by zero
pub fn divide(a: Int, b: Int) -> Result(Int, String) {
  case b {
    0 -> Error("Cannot divide by zero")
    _ -> Ok(a / b)
  }
}
