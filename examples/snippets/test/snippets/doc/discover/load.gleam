import dream_test/discover.{type LoadResult}

pub fn main() -> LoadResult {
  discover.tests("snippets/unit/**.gleam")
  |> discover.load()
}
