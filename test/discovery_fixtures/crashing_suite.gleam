//// A test module whose `tests()` crashes, for discovery load errors.

import dream_test/suite.{type TestSuite}

pub fn tests() -> TestSuite {
  panic as "crashing_suite fixture"
}
