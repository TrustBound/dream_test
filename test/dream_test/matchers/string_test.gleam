import dream_test/assertions/should.{
  contain_string, end_with, or_fail_with, should, start_with,
}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed_result.{be_match_failed_result}
import matchers/be_match_ok_result.{be_match_ok_result}

pub fn tests() {
  describe("String Matchers", [
    group("start_with", [
      it("returns MatchOk when string starts with prefix", fn(_) {
        "Hello, world!"
        |> should()
        |> start_with("Hello")
        |> be_match_ok_result()
        |> or_fail_with("start_with should pass when string starts with prefix")
      }),
      it("returns MatchFailed when string does not start with prefix", fn(_) {
        "Hello, world!"
        |> should()
        |> start_with("world")
        |> be_match_failed_result()
        |> or_fail_with(
          "start_with should fail when string does not start with prefix",
        )
      }),
      it("works with empty prefix", fn(_) {
        "Hello, world!"
        |> should()
        |> start_with("")
        |> be_match_ok_result()
        |> or_fail_with("start_with should pass for empty prefix")
      }),
    ]),
    group("end_with", [
      it("returns MatchOk when string ends with suffix", fn(_) {
        "Hello, world!"
        |> should()
        |> end_with("world!")
        |> be_match_ok_result()
        |> or_fail_with("end_with should pass when string ends with suffix")
      }),
      it("returns MatchFailed when string does not end with suffix", fn(_) {
        "Hello, world!"
        |> should()
        |> end_with("Hello")
        |> be_match_failed_result()
        |> or_fail_with(
          "end_with should fail when string does not end with suffix",
        )
      }),
    ]),
    group("contain_string", [
      it("returns MatchOk when string contains substring", fn(_) {
        "Hello, world!"
        |> should()
        |> contain_string(", ")
        |> be_match_ok_result()
        |> or_fail_with(
          "contain_string should pass when string contains substring",
        )
      }),
      it("returns MatchFailed when string does not contain substring", fn(_) {
        "Hello, world!"
        |> should()
        |> contain_string("xyz")
        |> be_match_failed_result()
        |> or_fail_with(
          "contain_string should fail when string does not contain substring",
        )
      }),
      it("finds substring at start of string", fn(_) {
        "Hello, world!"
        |> should()
        |> contain_string("Hello")
        |> be_match_ok_result()
        |> or_fail_with("contain_string should find substring at start")
      }),
      it("finds substring at end of string", fn(_) {
        "Hello, world!"
        |> should()
        |> contain_string("world!")
        |> be_match_ok_result()
        |> or_fail_with("contain_string should find substring at end")
      }),
    ]),
  ])
}
