import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/dynamic
import gleam/erlang/process

pub fn tests() -> TestSuite {
  describe("Exit reasons", [
    it("format_exit_reason shows an abnormal reason as Gleam text", fn() {
      process.Abnormal(dynamic.string("boom"))
      |> sandbox.format_exit_reason
      |> should
      |> be_equal("\"boom\"")
      |> or_fail_with("expected the quoted reason")
    }),
  ])
}
