import dream_test/file.{NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets/guides/hooks_user_files.{alice_file}

pub fn tests() {
  describe("The user file hooks", [
    it("remove the file after the last test", fn() {
      // Arrange
      let suite = hooks_user_files.tests()

      // Act
      runner.new([suite])
      |> runner.silent()
      |> runner.run()
      let after_the_run = file.read(alice_file)

      // Assert
      after_the_run
      |> should
      |> be_equal(Error(NotFound(alice_file)))
      |> or_fail_with("after_all should delete the file")
    }),
  ])
}
