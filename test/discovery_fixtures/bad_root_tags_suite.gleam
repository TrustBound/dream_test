//// A test module whose suite has a tag that is not a string, for
//// discovery load errors.

import dream_test/types.{type TestSuite, Root}

pub fn tests() -> TestSuite(Nil) {
  Root(seed: Nil, name: "bad_root_tags_suite", tags: [coerce(1)], children: [])
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> b
