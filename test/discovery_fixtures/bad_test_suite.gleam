//// A test module whose suite has a test with a tag that is not a string,
//// for discovery load errors.

import dream_test/types.{type TestSuite, Root}
import dream_test/unit.{it, with_tags}

pub fn tests() -> TestSuite(Nil) {
  Root(seed: Nil, name: "bad_test_suite", tags: [], children: [
    it("bad", fn() { Ok(types.AssertionOk) })
    |> with_tags([coerce(1)]),
  ])
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> b
