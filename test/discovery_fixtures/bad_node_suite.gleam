//// A test module whose suite has a child that is not a node, after a
//// valid group, for discovery load errors.

import dream_test/types.{type TestSuite, AssertionOk, Root}
import dream_test/unit.{after_all, after_each, before_each, group, it, with_tags}

pub fn tests() -> TestSuite(Nil) {
  Root(seed: Nil, name: "bad_node_suite", tags: [], children: [
    group("valid", [
      before_each(fn() { Ok(Nil) }),
      after_each(fn() { Ok(Nil) }),
      after_all(fn() { Ok(Nil) }),
      it("passes", fn() { Ok(AssertionOk) }) |> with_tags(["fast"]),
    ]),
    coerce(42),
  ])
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> b
