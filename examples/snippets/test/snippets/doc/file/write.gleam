import dream_test/file.{error_to_string, write}
import dream_test/process.{unique_port}
import gleam/int
import gleam/result

fn temporary_path() -> String {
  "build/tmp/file_example_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn write_a_greeting() -> Result(Nil, String) {
  let path = temporary_path()

  write(path, "hello") |> result.map_error(error_to_string)
}
