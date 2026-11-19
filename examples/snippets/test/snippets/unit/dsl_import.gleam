import dream_test/matchers.{succeed}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("unit DSL", [
    it("receives no context", fn() { Ok(succeed()) }),
  ])
}
