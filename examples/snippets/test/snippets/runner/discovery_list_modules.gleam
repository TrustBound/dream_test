import dream_test/discover

pub fn main() {
  discover.tests("snippets/unit/**.gleam")
  |> discover.list_modules()
}
