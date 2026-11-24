import gleam/io
import gleam/string

pub fn log(message: String) -> Nil {
  // coverage:ignore
  io.println(message)
}

// coverage:ignore-start debug helpers
pub fn dump(value: a) -> a {
  echo value
}

// coverage:ignore-end

// coverage:ignore-function only old callers use this
/// Converts the old record format.
@deprecated("Use convert instead")
pub fn convert_legacy(record: String) -> String {
  string.replace(record, ";", ",")
}
