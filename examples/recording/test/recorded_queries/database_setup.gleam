//// The setup and the teardown of the database suites: a recorder, and a
//// connection from it.

import dream_postgres/client as postgres
import dream_postgres/recorder
import dream_postgres/recording.{
  type RecordedQuery, type RecordedResult, Returned, Text, Tuple,
}
import dream_postgres_client.{type Connection}
import envoy
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string

/// What each database test gets: the connection, and the recorder that
/// made it.
pub type Database {
  Database(db: Connection, recorder: recorder.Recorder)
}

/// The database of `make db-up`. Only a record run connects to it.
const database_url = "postgresql://dream:dream@localhost:5438/recording"

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no database.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}

/// Starts a recorder that keeps the queries in
/// `test/recordings/queries/<name>.json`, connects, and makes the schema.
pub fn start_database(
  mode: recorder.Mode,
  name: String,
) -> Result(Database, String) {
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/queries")
    |> recorder.name(name)
    |> recorder.mode(mode)
    |> recorder.result_transformer(hide_share_tokens)
    |> recorder.start(),
  )
  use config <- result.try(
    postgres.parse_config(process.new_name("recorded_queries"), database_url)
    |> result.map_error(string.inspect),
  )
  // In playback mode, nothing connects to the database
  use db <- result.try(
    recorder.connect(recorder, config) |> result.map_error(string.inspect),
  )
  use Nil <- result.try(create_schema(db))
  Ok(Database(db:, recorder:))
}

pub fn stop_database(database: Database) -> Result(Nil, String) {
  recorder.stop(database.recorder)
}

// The schema queries go through the recorder too, so playback answers
// them from the file.
fn create_schema(db: Connection) -> Result(Nil, String) {
  [
    "DROP TABLE IF EXISTS tasks",
    "CREATE TABLE tasks (id serial PRIMARY KEY, title text NOT NULL, done boolean NOT NULL DEFAULT false, share_token text NOT NULL DEFAULT md5(random()::text))",
  ]
  |> list.try_each(fn(sql) {
    dream_postgres_client.query(sql)
    |> dream_postgres_client.execute(db)
    |> result.map_error(describe_query_error)
  })
}

/// The `RecorderError` of a query that the recorder failed, or the query
/// error of the database.
pub fn describe_query_error(error: dream_postgres_client.QueryError) -> String {
  case recorder.error(error) {
    Ok(recorder_error) -> string.inspect(recorder_error)
    Error(Nil) -> string.inspect(error)
  }
}

/// Runs in record mode only, before the recorder writes a result: the
/// file never holds a share token.
fn hide_share_tokens(
  query: RecordedQuery,
  result: RecordedResult,
) -> RecordedResult {
  case string.starts_with(query.sql, "SELECT share_token"), result {
    True, Returned(count:, rows:) ->
      Returned(
        count:,
        rows: list.map(rows, fn(_row) { Tuple([Text("[hidden]")]) }),
      )
    _, _ -> result
  }
}
