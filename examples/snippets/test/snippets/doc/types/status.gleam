import dream_test/matchers.{succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{before_all, describe, it}

fn connect_to_database() -> Result(Nil, String) {
  Error("connection refused")
}

pub fn handles_failures() -> TestSuite {
  describe("Handles failures", [
    before_all(fn() {
      case connect_to_database() {
        Ok(_) -> Ok(Nil)
        Error(reason) -> Error("Database connection failed: " <> reason)
      }
    }),
    // If before_all fails, these tests are marked SetupFailed (not run)
    it("test1", fn() { Ok(succeed()) }),
    it("test2", fn() { Ok(succeed()) }),
  ])
}
