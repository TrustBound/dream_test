import dream_test/file
import dream_test/matchers.{be_equal, match_snapshot, or_fail_with, should}
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/result

const new_snapshot = "build/guide_snapshots/new.snap"

fn suite_with_a_new_snapshot() {
  describe("Receipt", [
    it("renders a new receipt", fn() {
      "TOTAL 0.00\n"
      |> should
      |> match_snapshot(new_snapshot)
      |> or_fail_with("the receipt should match the snapshot")
    }),
  ])
}

pub fn tests() {
  describe("A snapshot test with no snapshot file", [
    it("passes and writes the file", fn() {
      // Arrange
      use Nil <- result.try(
        file.delete(new_snapshot) |> result.map_error(file.error_to_string),
      )

      // Act
      let failed =
        runner.new([suite_with_a_new_snapshot()])
        |> runner.silent()
        |> runner.run()
        |> types.failed

      // Assert
      #(failed, file.read(new_snapshot))
      |> should
      |> be_equal(#(False, Ok("TOTAL 0.00\n")))
      |> or_fail_with("the run should pass and write the value")
    }),
  ])
}
