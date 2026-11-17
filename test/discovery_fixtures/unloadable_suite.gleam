//// A test module that no other module imports, so it is not loaded until
//// discovery loads it. A discovery test puts a broken copy of its beam file
//// first in the code path.

import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("unloadable_suite", [it("passes", fn() { Ok(AssertionOk) })])
}
