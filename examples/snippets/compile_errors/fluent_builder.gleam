//// The "Don't" example of rule 6 of STANDARDS.md: a fluent, curried
//// matcher. Dream Test has no `should` module, so this file does not
//// compile. The test in `snippets/standards/compile_errors.gleam` compiles
//// it and checks the error.

import dream_test/matchers.{or_fail_with}

pub fn check(value: Int, expected: Int) {
  value
  |> should.be_equal(expected)
  |> or_fail_with("message")
}
