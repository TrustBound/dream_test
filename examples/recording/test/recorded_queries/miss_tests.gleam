//// A query with no recording, for the guide "Test database code with
//// recorded queries". It fails on purpose, so the main run does not run
//// it: `outputs_tests` runs it and compares its report.

import app/tasks
import dream_postgres/recorder
import dream_test/context
import dream_test/matchers.{be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import recorded_queries/database_setup.{
  type Database, start_database, stop_database,
}

pub fn tests() -> TestSuite {
  describe(
    "Tasks",
    context.setup(
      fn() { start_database(recorder.Playback, "tasks") },
      teardown: stop_database,
    ),
    [
      it("finds the share token of task 42", fn(database: Database) {
        tasks.share_token(database.db, 42)
        |> result.map_error(recorder.error)
        |> should
        |> be_ok()
        |> or_fail_with("task 42 should have a share token")
      }),
    ],
  )
}
