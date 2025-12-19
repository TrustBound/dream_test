import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/string
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/string", [
    it("start_with passes when the prefix matches", fn() {
      "hello world"
      |> should
      |> string.start_with("hello")
      |> or_fail_with("should start with hello")
    }),

    it("end_with passes when the suffix matches", fn() {
      "hello world"
      |> should
      |> string.end_with("world")
      |> or_fail_with("should end with world")
    }),

    it("contain_string passes when substring exists", fn() {
      "hello world"
      |> should
      |> string.contain_string("lo wo")
      |> or_fail_with("should contain substring")
    }),
  ])
}
