//// A query with no recording, for the guide "Test database code with
//// recorded queries". It fails on purpose, so the main run does not run
//// it: `outputs_tests` runs it and compares its report.

import app/tasks
import dream_postgres/recorder
import dream_test/context
import dream_test/matchers.{fail_with, succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import recorded_queries/database_setup.{
  type Database, describe_query_error, start_database, stop_database,
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
        case tasks.share_token(database.db, 42) {
          Ok(_token) -> Ok(succeed())
          Error(error) -> Ok(fail_with(describe_query_error(error)))
        }
      }),
    ],
  )
}
