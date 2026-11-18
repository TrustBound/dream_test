//// A test module whose suite has children that are not a proper list, for
//// discovery load errors.

import dream_test/types.{type TestSuite, Root}
import dream_test/unit.{it}

pub fn tests() -> TestSuite(Nil) {
  Root(
    seed: Nil,
    name: "improper_children_suite",
    tags: [],
    children: improper([it("passes", fn() { Ok(types.AssertionOk) })], 42),
  )
}

/// `[first, ..] ++ tail` with a tail that is not a list.
@external(erlang, "erlang", "++")
fn improper(list: List(a), tail: Int) -> List(a)
