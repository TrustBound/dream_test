import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/result
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/result", [
    it("be_ok passes for Ok", fn() {
      Ok(1)
      |> should
      |> result.be_ok()
      |> or_fail_with("Ok(1) should be ok")
    }),

    it("be_error passes for Error", fn() {
      Error("nope")
      |> should
      |> result.be_error()
      |> or_fail_with("Error(\"nope\") should be error")
    }),
  ])
}
