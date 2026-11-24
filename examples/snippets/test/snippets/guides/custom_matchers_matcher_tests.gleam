import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, group, it}
import gleam/option.{None, Some}
import snippets/guides/custom_matchers_response.{
  Response, have_body, have_status,
}

pub fn tests() {
  describe("Response matchers", [
    group("have_status", [
      it("passes the response on when the status matches", fn() {
        // Arrange
        let response = Response(status: 200, body: "ok")

        // Act
        let result = have_status(MatchOk(response), 200)

        // Assert
        result
        |> should
        |> be_equal(MatchOk(response))
        |> or_fail_with("a matching status should pass the response on")
      }),
      it("fails with the actual status when it differs", fn() {
        // Arrange
        let response = Response(status: 404, body: "Not found")

        // Act
        let result = have_status(MatchOk(response), 200)

        // Assert
        result
        |> should
        |> be_equal(
          MatchFailed(AssertionFailure(
            operator: "have_status",
            message: "",
            payload: Some(CustomMatcherFailure(
              actual: "404",
              description: "expected the status 200",
            )),
          )),
        )
        |> or_fail_with("a different status should fail with both statuses")
      }),
      it("keeps a failure from an earlier matcher", fn() {
        // Arrange
        let earlier =
          AssertionFailure(operator: "be_ok", message: "", payload: None)

        // Act
        let result = have_status(MatchFailed(earlier), 200)

        // Assert
        result
        |> should
        |> be_equal(MatchFailed(earlier))
        |> or_fail_with("an earlier failure should pass through unchanged")
      }),
    ]),
    group("have_body", [
      it("passes the body on", fn() {
        // Act
        let result = have_body(MatchOk(Response(status: 200, body: "Hi")))

        // Assert
        result
        |> should
        |> be_equal(MatchOk("Hi"))
        |> or_fail_with("the next matcher should get the body")
      }),
    ]),
  ])
}
