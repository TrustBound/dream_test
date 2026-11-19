//// Fixture for the tests of `@external` functions. The expected line
//// numbers in test/dream_test/coverage_external_test.gleam come from this
//// file, so update them when you change it.

/// Doc comment before the attribute.
@external(erlang, "coverage_fixture_ffi", "double")
pub fn double(number number: Int) -> Int

@deprecated("Use double instead")
@external(erlang, "coverage_fixture_ffi", "double")
@external(javascript, "./external_wrapper.mjs", "double")
pub fn double_with_body(number: Int) -> Int {
  number * 2
}

@external(erlang, "coverage_fixture_ffi", "double")
fn private_double(number: Int) -> Int

pub fn quadruple(number: Int) -> Int {
  private_double(double(number))
}

pub fn double_reference() -> fn(Int) -> Int {
  double
}
