import dream_test/matchers.{contain_string, or_fail_with, should}
import dream_test/unit.{describe, it}
import snippets/guides/custom_matchers_response.{handle, have_body, have_status}

pub fn tests() {
  describe("handle", [
    it("greets a user by name", fn() {
      handle("/hello/alice")
      |> should
      |> have_status(200)
      |> have_body()
      |> contain_string("alice")
      |> or_fail_with("the greeting should name alice")
    }),
  ])
}

/// A test that fails at the custom matcher, for the report in the guide.
/// It is not in `tests`, so test discovery does not run it.
pub fn failing_tests() {
  describe("handle", [
    it("greets a user who is not there", fn() {
      handle("/hello")
      |> should
      |> have_status(200)
      |> have_body()
      |> contain_string("alice")
      |> or_fail_with("the greeting should name alice")
    }),
  ])
}
