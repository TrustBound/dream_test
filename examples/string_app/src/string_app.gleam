//// Simple string utilities for demonstration.
////
//// These functions wrap gleam/string to show how you might
//// build and test a utility module.

import gleam/string

/// Shout a message by converting it to uppercase and adding "!"
pub fn shout(message: String) -> String {
  string.uppercase(message) <> "!"
}

/// Whisper a message by converting it to lowercase
pub fn whisper(message: String) -> String {
  string.lowercase(message)
}

/// Clean up user input by trimming whitespace
pub fn clean(input: String) -> String {
  string.trim(input)
}

/// Greet someone by name, or return an error for empty names
pub fn greet(name: String) -> Result(String, String) {
  let cleaned = string.trim(name)
  case cleaned {
    "" -> Error("Name cannot be empty")
    _ -> Ok("Hello, " <> cleaned <> "!")
  }
}
