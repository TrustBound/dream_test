//// A test module whose `tests()` crashes, for discovery load errors.

import dream_test/types.{type TestSuite}

pub fn tests() -> TestSuite(Nil) {
  panic as "crashing_suite fixture"
}
