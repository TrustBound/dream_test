//// A test module with a hook and one passing test, for discovery.

import dream_test/types.{AssertionOk}
import dream_test/unit.{before_all, describe, it}

pub fn tests() {
  describe("hooked_suite", [
    before_all(fn() { Ok(Nil) }),
    it("passes", fn() { Ok(AssertionOk) }),
  ])
}
