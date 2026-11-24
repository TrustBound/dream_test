import dream_test/types
import gleam/option.{None}

pub fn math_tree() -> types.Tree(Nil) {
  types.Tree(initial: Nil, name: "math", tags: [], tests: [
    types.Test(
      name: "adds",
      tags: [],
      kind: types.Unit,
      run: types.WithInput(fn(_context) { Ok(types.AssertionOk) }),
      timeout_ms: None,
      source: None,
    ),
  ])
}
