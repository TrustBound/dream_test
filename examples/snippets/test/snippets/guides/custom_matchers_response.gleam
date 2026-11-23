import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{Some}

/// A response of your web handler.
pub type Response {
  Response(status: Int, body: String)
}

/// The handler under test.
pub fn handle(path: String) -> Response {
  case path {
    "/hello/" <> name -> Response(status: 200, body: "Hello, " <> name)
    _ -> Response(status: 404, body: "Not found")
  }
}

/// Passes when the response has the status `expected`. The next matcher
/// gets the same response.
pub fn have_status(
  result: MatchResult(Response),
  expected: Int,
) -> MatchResult(Response) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> check_status(response, expected)
  }
}

fn check_status(response: Response, expected: Int) -> MatchResult(Response) {
  case response.status == expected {
    True -> MatchOk(response)
    False ->
      MatchFailed(AssertionFailure(
        operator: "have_status",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(response.status),
          description: "expected the status " <> int.to_string(expected),
        )),
      ))
  }
}

/// Unwraps the body of the response. The next matcher gets the body.
pub fn have_body(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> MatchOk(response.body)
  }
}

pub fn tests() {
  describe("handle", [
    it("greets the name in the path", fn() {
      // Act
      let response = handle("/hello/alice")

      // Assert
      response
      |> should
      |> be_equal(Response(status: 200, body: "Hello, alice"))
      |> or_fail_with("the handler should greet alice")
    }),
    it("answers 404 for another path", fn() {
      // Act
      let response = handle("/hello")

      // Assert
      response
      |> should
      |> be_equal(Response(status: 404, body: "Not found"))
      |> or_fail_with("the handler should not know /hello")
    }),
  ])
}
