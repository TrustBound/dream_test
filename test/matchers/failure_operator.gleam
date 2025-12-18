import dream_test/types
import gleam/option.{None}

pub fn have_failure_operator(
  result: types.MatchResult(a),
  expected_operator: String,
) -> types.MatchResult(types.AssertionFailure) {
  case result {
    types.MatchOk(_) ->
      types.MatchFailed(types.AssertionFailure(
        operator: "have_failure_operator",
        message: "expected MatchFailed("
          <> expected_operator
          <> ") but got MatchOk",
        payload: None,
      ))

    types.MatchFailed(failure) ->
      case failure.operator == expected_operator {
        True -> types.MatchOk(failure)
        False ->
          types.MatchFailed(types.AssertionFailure(
            operator: "have_failure_operator",
            message: "expected operator "
              <> expected_operator
              <> " but got "
              <> failure.operator,
            payload: None,
          ))
      }
  }
}
