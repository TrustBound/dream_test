import dream_test/gherkin/discover
import dream_test/matchers.{contain, have_length, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Gherkin discovery", [
    it("list_files returns matching .feature file paths", fn() {
      discover.features("test/*.feature")
      |> discover.list_files()
      |> should
      |> contain("test/cart.feature")
      |> or_fail_with("expected list_files to include test/cart.feature")
    }),
    it("load returns parsed features (and collects errors)", fn() {
      let result = discover.features("test/*.feature") |> discover.load()

      result.features
      |> should
      |> have_length(1)
      |> or_fail_with("expected one parsed feature")
    }),
  ])
}
