import dream_test/matchers.{
  contain_string, end_with, or_fail_with, should, start_with,
}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: strings", [
    it("start_with checks the start of a string", fn() {
      "hello world"
      |> should
      |> start_with("hello")
      |> or_fail_with("expected string to start with \"hello\"")
    }),
    it("end_with checks the end of a string", fn() {
      "hello.gleam"
      |> should
      |> end_with(".gleam")
      |> or_fail_with("expected .gleam suffix")
    }),
    it("contain_string checks a string contains a substring", fn() {
      "hello world"
      |> should
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
  ])
}
