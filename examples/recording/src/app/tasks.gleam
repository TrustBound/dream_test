//// A to-do list in PostgreSQL: the code under test of the guide "Test
//// database code with recorded queries". Each function takes the
//// connection as its first parameter, so a test can give it a recorded
//// connection.

import dream_postgres_client.{type Connection, type QueryError}
import gleam/dynamic/decode
import gleam/list
import gleam/result

pub type Task {
  Task(id: Int, title: String)
}

pub type CompleteError {
  NoSuchTask(id: Int)
  CompleteFailed(error: QueryError)
}

/// Adds a task, and gives its id.
pub fn add_task(db: Connection, title: String) -> Result(Int, QueryError) {
  dream_postgres_client.query(
    "INSERT INTO tasks (title) VALUES ($1) RETURNING id",
  )
  |> dream_postgres_client.parameter(dream_postgres_client.text(title))
  |> dream_postgres_client.returning(decode.at([0], decode.int))
  |> dream_postgres_client.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.try(first_row)
}

/// The tasks that are not done, oldest first.
pub fn open_tasks(db: Connection) -> Result(List(Task), QueryError) {
  dream_postgres_client.query(
    "SELECT id, title FROM tasks WHERE NOT done ORDER BY id",
  )
  |> dream_postgres_client.returning({
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    decode.success(Task(id:, title:))
  })
  |> dream_postgres_client.execute(db)
  |> result.map(fn(returned) { returned.rows })
}

/// Marks all the tasks as done, or none of them: when one id has no task,
/// the transaction rolls back.
pub fn complete_tasks(
  db: Connection,
  ids: List(Int),
) -> Result(Nil, dream_postgres_client.TransactionError(CompleteError)) {
  use transaction <- dream_postgres_client.transaction(db)
  list.try_each(ids, fn(id) { complete_task(transaction, id) })
}

fn complete_task(db: Connection, id: Int) -> Result(Nil, CompleteError) {
  let updated =
    dream_postgres_client.query("UPDATE tasks SET done = true WHERE id = $1")
    |> dream_postgres_client.parameter(dream_postgres_client.int(id))
    |> dream_postgres_client.execute(db)
  case updated {
    Ok(returned) if returned.count == 1 -> Ok(Nil)
    Ok(_) -> Error(NoSuchTask(id))
    Error(error) -> Error(CompleteFailed(error))
  }
}

/// The secret token of the share link of a task.
pub fn share_token(db: Connection, id: Int) -> Result(String, QueryError) {
  dream_postgres_client.query("SELECT share_token FROM tasks WHERE id = $1")
  |> dream_postgres_client.parameter(dream_postgres_client.int(id))
  |> dream_postgres_client.returning(decode.at([0], decode.string))
  |> dream_postgres_client.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.try(first_row)
}

// No row is an error here, so a test sees it.
fn first_row(rows: List(a)) -> Result(a, QueryError) {
  case rows {
    [row, ..] -> Ok(row)
    [] ->
      Error(dream_postgres_client.PostgresqlError(
        "P0002",
        "no_data_found",
        "No row",
      ))
  }
}
