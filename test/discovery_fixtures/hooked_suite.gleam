//// A test module with a hook, a passing test and a passing test in a
//// nested group, for discovery.

import dream_test/types.{AssertionOk}
import dream_test/unit.{before_all, describe, group, it}

pub fn tests() {
  describe("hooked_suite", [
    before_all(fn() { Ok(Nil) }),
    it("passes", fn() { Ok(AssertionOk) }),
    group("nested", [it("passes too", fn() { Ok(AssertionOk) })]),
  ])
}
