import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/result
import snippets/doc/reporters/progress/line
import snippets/doc/reporters/progress/progress_event
import snippets/doc/reporters/progress/render
import snippets_child_vm.{ChildRun, it_runs_in_child_vm, progress_done_line}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/progress", [
    it_runs_in_child_vm("new main ends with a full bar for three tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/progress/new", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(3) <> "",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the progress line to end with a full bar")
    }),
    it_runs_in_child_vm("progress_reporter main ends with a full bar", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/reporters/progress_reporter", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2) <> "",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the progress line to end with a full bar")
    }),
    it("finished_line_ends_the_bar passes", fn() {
      // Act
      let result = progress_event.finished_line_ends_the_bar()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected finished_line_ends_the_bar to pass")
    }),
    it("started_line_shows_an_empty_bar passes", fn() {
      // Act
      let result = line.started_line_shows_an_empty_bar()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected started_line_shows_an_empty_bar to pass")
    }),
    it("started_render_is_an_empty_bar passes", fn() {
      // Act
      let result = render.started_render_is_an_empty_bar()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected started_render_is_an_empty_bar to pass")
    }),
  ])
}
