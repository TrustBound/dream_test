import dream_test/discover

pub fn main() -> Result(List(String), String) {
  discover.tests("snippets/unit/**.gleam")
  |> discover.list_modules()
}
