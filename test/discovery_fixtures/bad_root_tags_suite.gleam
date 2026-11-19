//// A test module whose `tests()` returns a typed tree with a tag that is
//// not a string, not a suite, for discovery load errors.

import dream_test/types.{type Root, Root}

pub fn tests() -> Root(Nil) {
  Root(seed: Nil, name: "bad_root_tags_suite", tags: [coerce(1)], children: [])
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> b
