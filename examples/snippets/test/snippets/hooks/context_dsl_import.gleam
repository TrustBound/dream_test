import dream_test/context
import dream_test/matchers.{succeed}
import dream_test/unit_context.{describe, it}

pub fn tests() {
  describe("unit_context DSL", context.value(0), [
    it("receives the context", fn(_context: Int) { Ok(succeed()) }),
  ])
}
