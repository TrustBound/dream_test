//// The task suite of the guide "Test database code with recorded
//// queries". The tests share one table, so the run gives this suite
//// `max_concurrency: 1`.

import app/tasks.{NoSuchTask, Task}
import dream_postgres_client.{TransactionRolledBack}
import dream_test/context
import dream_test/matchers.{
  be_equal, be_ok, contain, not_contain, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/list
import gleam/result
import gleam/string
import recorded_queries/database_setup.{
  type Database, recorder_mode, start_database, stop_database,
}

pub fn tests() -> TestSuite {
  describe(
    "Tasks",
    context.setup(start_task_database, teardown: stop_database),
    [
      it("lists a new task as open", fn(database: Database) {
        use id <- result.try(add(database, "Buy milk"))
        tasks.open_tasks(database.db)
        |> should
        |> be_ok()
        |> contain(Task(id, "Buy milk"))
        |> or_fail_with("the new task should be open")
      }),
      it("completes tasks in one transaction", fn(database: Database) {
        use rent <- result.try(add(database, "Pay rent"))
        use bank <- result.try(add(database, "Call the bank"))
        use Nil <- result.try(
          tasks.complete_tasks(database.db, [rent, bank])
          |> result.map_error(string.inspect),
        )
        tasks.open_tasks(database.db)
        |> should
        |> be_ok()
        |> not_contain(Task(rent, "Pay rent"))
        |> not_contain(Task(bank, "Call the bank"))
        |> or_fail_with("both tasks should be done")
      }),
      it("rolls back when one task does not exist", fn(database: Database) {
        use flights <- result.try(add(database, "Book flights"))
        let completed = tasks.complete_tasks(database.db, [flights, 999])
        use open <- result.try(
          tasks.open_tasks(database.db) |> result.map_error(string.inspect),
        )
        #(completed, list.contains(open, Task(flights, "Book flights")))
        |> should
        |> be_equal(#(Error(TransactionRolledBack(NoSuchTask(999))), True))
        |> or_fail_with("the transaction should roll back, and keep the task")
      }),
      it("gives the share token of a task", fn(database: Database) {
        use id <- result.try(add(database, "Plan the party"))
        // Playback gives "[hidden]": the recorder never wrote the token
        tasks.share_token(database.db, id)
        |> result.map(string.is_empty)
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("the task should have a share token")
      }),
    ],
  )
}

fn start_task_database() -> Result(Database, String) {
  use mode <- result.try(recorder_mode())
  start_database(mode, "tasks")
}

fn add(database: Database, title: String) -> Result(Int, String) {
  tasks.add_task(database.db, title) |> result.map_error(string.inspect)
}
