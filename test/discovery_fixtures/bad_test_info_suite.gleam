//// A test module whose `tests()` returns a value with the shape of a
//// suite and a test that is not a `TestInfo`, for discovery load errors.

import gleam/erlang/atom
import gleam/option.{None}

pub fn tests() {
  #(atom.create("test_suite"), "bad_test_info_suite", [
    #(
      atom.create("part"),
      #(atom.create("place"), [], None),
      [Nil],
      tests_at,
      run,
    ),
  ])
}

fn tests_at(_place: Nil) -> List(Nil) {
  []
}

fn run(_place: Nil, _input: Nil) -> Nil {
  Nil
}
