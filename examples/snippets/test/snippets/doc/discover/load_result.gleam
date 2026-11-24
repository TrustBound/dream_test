import dream_test/discover
import dream_test/suite.{type TestSuite}

pub fn loaded_suites() -> List(TestSuite) {
  let discover.LoadResult(suites: suites, errors: _errors) =
    discover.tests("snippets/**.gleam")
    |> discover.load()
  suites
}
