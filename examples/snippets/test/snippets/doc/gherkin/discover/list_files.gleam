import dream_test/gherkin/discover
import dream_test/matchers.{be_ok, contain, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn list_files_finds_the_cart_feature() -> Result(AssertionResult, String) {
  discover.features("test/*.feature")
  |> discover.list_files()
  |> should
  |> be_ok()
  |> contain("test/cart.feature")
  |> or_fail_with("expected list_files to include test/cart.feature")
}
