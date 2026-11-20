//// A test module whose `tests()` returns a typed tree with a tag that is
//// not a string, not a suite, for discovery load errors.

import dream_test/types.{type Tree, Tree}

pub fn tests() -> Tree(Nil) {
  Tree(seed: Nil, name: "bad_root_tags_suite", tags: [coerce(1)], children: [])
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> b
