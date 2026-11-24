//// 2.x suite code that 3.0.0 does not compile: `TestSuite` has no type
//// parameter now, and lives in `dream_test/suite`. The upgrade guide shows
//// the compiler error, and the test in `snippets/guides/upgrading_tests.gleam`
//// compiles this file and checks it.

import dream_test/types.{type TestSuite}
import dream_test/unit.{describe}

pub fn tests() -> TestSuite(Nil) {
  describe("Cart", [])
}
