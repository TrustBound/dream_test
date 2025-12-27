import dream_test/discover.{from_path, list_modules}
import dream_test/matchers.{be_equal, contain, have_length, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/discover", [
    it("can discover a specific test module", fn() {
      let result =
        discover.new()
        |> from_path("dream_test/unit_api_test.gleam")
        |> list_modules()

      result
      |> should
      |> be_equal(Ok(["dream_test@unit_api_test"]))
      |> or_fail_with("expected discovery to find the unit_api_test module")
    }),

    it("dedupes modules when the same path is added twice", fn() {
      let result =
        discover.new()
        |> from_path("dream_test/unit_api_test.gleam")
        |> from_path("dream_test/unit_api_test.gleam")
        |> list_modules()

      let assert Ok(mods) = result

      mods
      |> should
      |> have_length(1)
      |> contain("dream_test@unit_api_test")
      |> or_fail_with("expected no duplicates")
    }),
  ])
}
