//// A test module whose `tests()` returns a value with the tag of a suite
//// and a part that is not a part, for discovery load errors.

import gleam/erlang/atom

pub fn tests() {
  #(atom.create("test_suite"), "bad_part_suite", [Nil])
}
