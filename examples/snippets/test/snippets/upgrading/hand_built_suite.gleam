import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type Node, BeforeAll, NoInput, Test, Tree, Unit, WithInput,
}
import gleam/int
import gleam/list
import gleam/option.{None}

fn doubling_cases() -> List(#(Int, Int)) {
  [#(1, 2), #(2, 4), #(21, 42)]
}

fn check_tables() -> Result(Nil, String) {
  Ok(Nil)
}

fn doubling_test(pair: #(Int, Int)) -> Node(Nil) {
  let #(input, expected) = pair
  Test(
    name: "doubles " <> int.to_string(input),
    tags: [],
    kind: Unit,
    run: WithInput(fn(_context: Nil) {
      input * 2
      |> should
      |> be_equal(expected)
      |> or_fail_with("wrong double")
    }),
    timeout_ms: None,
    source: None,
  )
}

pub fn tests() -> TestSuite {
  suite.from_tree(
    Tree(initial: Nil, name: "doubling", tags: [], tests: [
      BeforeAll(NoInput(check_tables)),
      ..list.map(doubling_cases(), doubling_test)
    ]),
  )
}
