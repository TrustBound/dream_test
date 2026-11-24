import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/unit.{describe}
import dream_test/unit_context.{it}

/// The user store suite with a setup that cannot start the store.
pub fn store_down_tests() {
  unit_context.describe(
    "User store",
    context.setup(
      fn() { Error("the store did not start: port 7000 is in use") },
      teardown: fn(_store: Nil) { Ok(Nil) },
    ),
    [
      it("finds a user by id", fn(_store: Nil) {
        1
        |> should
        |> be_equal(1)
        |> or_fail_with("never runs")
      }),
    ],
  )
}

pub fn tests() {
  describe("A context setup that fails", [
    unit.it("gives SetupFailed", fn() {
      // Act
      let report =
        runner.new([store_down_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).setup_failed
      |> should
      |> be_equal(1)
      |> or_fail_with("the test should be SetupFailed")
    }),
  ])
}
