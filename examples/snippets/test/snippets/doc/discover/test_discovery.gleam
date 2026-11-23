import dream_test/discover.{type LoadResult}

pub fn load_unit_snippets() -> LoadResult {
  discover.tests("snippets/unit/**.gleam")
  |> discover.load()
}
