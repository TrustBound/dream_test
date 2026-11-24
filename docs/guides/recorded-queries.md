# Test database code with recorded queries

Why this approach: [Mock at the system boundary](https://github.com/TrustBound/dream_test/blob/main/docs/guides/mock-at-the-boundary.md).

A test against a real database needs a PostgreSQL server on each machine that runs it, CI included. The server must start before the tests, and each run must start from the same data. When the server is not there, every test fails. A recording removes that need. You run the tests one time against PostgreSQL, and the recorder of [dream_postgres](https://github.com/TrustBound/dream_postgres) writes each query and its real result to a file. After that, the tests play the file back with no database at all. This guide builds a test suite for a small to-do list. The suite records with one command against a PostgreSQL server in Docker, and plays back in CI, where no database runs.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which mode to use](#which-mode-to-use)
- [Step 1: Write code that takes a connection](#step-1-write-code-that-takes-a-connection)
- [Step 2: Start the recorder in the suite setup](#step-2-start-the-recorder-in-the-suite-setup)
- [Step 3: Make the schema through the recorder](#step-3-make-the-schema-through-the-recorder)
- [Step 4: Write the tests and run them one at a time](#step-4-write-the-tests-and-run-them-one-at-a-time)
- [Step 5: Record one time against PostgreSQL](#step-5-record-one-time-against-postgresql)
- [Step 6: Play back with no database](#step-6-play-back-with-no-database)
- [Step 7: Test a transaction](#step-7-test-a-transaction)
- [Step 8: Read a query with no recording](#step-8-read-a-query-with-no-recording)
- [Keep secrets out of the file](#keep-secrets-out-of-the-file)
- [How a query finds its recording](#how-a-query-finds-its-recording)
- [Refresh the recordings](#refresh-the-recordings)
- [Run the tests in CI](#run-the-tests-in-ci)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, you will:

- Write query functions that do not know about recordings.
- Start a recorder in the setup of a suite, get a connection from it, and stop it in the teardown.
- Choose the mode with an environment variable: `record` on your machine, playback in CI.
- Record the suite one time against PostgreSQL in Docker.
- Play the suite back with the database stopped.
- Test a transaction that rolls back.
- Read the error of a query that has no recording.
- Keep a secret token out of the recording file.

## Before you start

You need a project with Dream Test and a test runner. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up. This guide also uses `unit_context.describe` with `context.setup`, which [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md#step-3-get-the-context-from-a-setup) explains.

The code of this guide is the project `examples/recording` in the Dream Test repository. Its tests run in CI on each change. `dream_postgres` is not on Hex yet, so the project gets it from GitHub. `dream_postgres_client` is the driver, a fork of Pog:

### The database packages <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/gleam.toml#L14-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
# Switched to a Hex version range once it is published.
dream_postgres = { git = "https://github.com/TrustBound/dream_postgres.git", ref = "ee7d9c8cc16be3154895a39e942f5cafc62caa09" }
dream_postgres_client = ">= 1.0.0 and < 2.0.0"
```

The tests read an environment variable with `envoy`, a dev dependency. Only the record run needs PostgreSQL. The project starts it in Docker, with this `docker-compose.yml`:

### The database of the record run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/docker-compose.yml#L5-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
name: dream_test_recording

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: dream
      POSTGRES_PASSWORD: dream
      POSTGRES_DB: recording
    ports:
      # Port 5438 on this machine, so the record run does not use a
      # PostgreSQL server that already listens on 5432.
      - "5438:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dream -d recording"]
      interval: 1s
      timeout: 5s
      retries: 30
```

The server keeps no data. Each start gives an empty database. The outputs on this page are real outputs of the code shown, with every time set to 0. A test of the project compares each output with the real report.

## Which mode to use

A recorder runs in one of three modes. Each mode is a value of the type `recorder.Mode`, so the compiler rejects a wrong name:

| Your situation | Mode | What happens |
|:---|:---|:---|
| You want a new recording from the real database | `recorder.Record` | Each query runs on the database. The recorder writes the query, its parameters and its result to the file before the query returns. |
| The tests must run with no database, as in CI | `recorder.Playback` | No pool starts and nothing connects. Each query gets the result of its recording. A query with no recording fails with an error that names it. |
| The recorder is in place, but you want live queries for now | `recorder.Passthrough` | Each query runs on the database, and nothing is written. |

The names are the same as the modes of the HTTP recorder of [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md). The full API of the recorder is in the guide [Test database code with recorded queries](https://github.com/TrustBound/dream_postgres/blob/main/docs/guides/recorded-queries.md) of `dream_postgres`. This guide shows how to fit it into a Dream Test suite.

## Step 1: Write code that takes a connection

The code under test is a to-do list. Each function takes the connection as its first parameter:

### The task queries <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/src/app/tasks.gleam#L11-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

This is the one thing that makes recordings easy. The test decides which connection to give: a pool, a pool that records, or a connection that plays back. The code does not change.

## Step 2: Start the recorder in the suite setup

You record on your machine, and CI plays back. So the mode comes from an environment variable, `RECORDER_MODE`. `recorder.parse_mode` turns the text into a `recorder.Mode`. It accepts `record`, `playback` and `passthrough`, and gives an `Error` that names any other text. With no variable, the tests play back.

A recorder is a process, so something must start it before the first test and stop it after the last test. In Dream Test, that is the `setup` and the `teardown` of `context.setup`, which `unit_context.describe` takes. The setup runs one time for the suite, and its value is the context of each test. Here the context is `Database`: the connection and its recorder:

### Start the recorder and connect <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/database_setup.gleam#L16-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

How it works:

- A recorder keeps the queries of one suite in one file, `<directory>/<name>.json`. Give each suite its own name.
- `recorder.connect` takes the `Config` of the database. In record and passthrough mode, it starts the pool. In playback mode, it starts no pool and opens no connection, so the database does not have to exist.
- In record mode, `recorder.start` writes an empty file at once. So a record run never keeps the queries of an earlier run.
- When the setup returns an `Error`, no test of the suite runs, and the report shows the message.
- `hide_share_tokens` keeps a secret out of the file. [Keep secrets out of the file](#keep-secrets-out-of-the-file) shows it.

Why not `before_all` and `after_all` of `dream_test/unit`? Those hooks return `Ok(Nil)`, so they cannot give the connection to the tests. `context.setup` gives the value of the setup to each test, with its type.

## Step 3: Make the schema through the recorder

The record run starts from an empty database, so the setup makes the table. It sends the schema queries through the recorded connection, like any other query:

### Make the schema <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/database_setup.gleam#L64-L85"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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

/// The text of the `RecorderError` of a query that the recorder failed,
/// or the query error of the database.
pub fn describe_query_error(error: dream_postgres_client.QueryError) -> String {
  case recorder.error(error) {
    Ok(recorder_error) -> recorder.describe_error(recorder_error)
    Error(Nil) -> string.inspect(error)
  }
}
```

So the setup has the same code in each mode. In playback, the schema queries get their recorded results, and nothing runs. `describe_query_error` makes the message of a failed setup readable: [Step 8](#step-8-read-a-query-with-no-recording) shows `recorder.error` and `recorder.describe_error`.

## Step 4: Write the tests and run them one at a time

Each test gets the `Database` and passes `database.db` to the code under test:

### The task suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/tasks_tests.gleam#L20-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The suite has two more tests, for the transaction of Step 7 and the secret of [Keep secrets out of the file](#keep-secrets-out-of-the-file). Its setup reads the mode, and starts the recorder with the name `tasks`:

### The setup of the task suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/tasks_tests.gleam#L71-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn start_task_database() -> Result(Database, String) {
  use mode <- result.try(recorder_mode())
  start_database(mode, "tasks")
}

fn add(database: Database, title: String) -> Result(Int, String) {
  tasks.add_task(database.db, title) |> result.map_error(string.inspect)
}
```

The tests share one table. Dream Test runs the tests of a group in parallel, so a record run would get the queries in a different order each time, and other ids. The test `main` gives this suite `max_concurrency: 1`, so its tests run one at a time, in order:

### Run the task suite one test at a time <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recording_test.gleam#L10-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([forecast_tests.tests(), alerts_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [tasks_tests.tests()])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The task tests share one table, so they run one at a time, in order.
fn one_at_a_time() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 10_000)
}
```

The HTTP suites of the other guide keep the default concurrency. `output_checks` are the tests that compare the outputs of this page.

## Step 5: Record one time against PostgreSQL

The record script of the project starts the database, runs the tests with `RECORDER_MODE=record`, and stops the database when the run ends, also when it fails:

### Record with the database up <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/record.sh#L8-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
```

`make record` runs it. The queries run on PostgreSQL, and the tests get the live results. The recorder writes `test/recordings/queries/tasks.json`. Each query has its SQL, its parameters and its result: the row count and the rows, or the error. The keys always come in the same order, so the diff of two recordings shows only what changed. [The `recording` module](https://hexdocs.pm/dream_postgres/dream_postgres/recording.html) documents the format.

Read the new file before you commit it, then commit it with the tests.

## Step 6: Play back with no database

Now run `gleam test` with no variable. The database is stopped, and nothing listens on port 5438. The tests pass from the file:

### The report of a playback run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/queries_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Tasks
  ✓ lists a new task as open
  ✓ completes tasks in one transaction
  ✓ rolls back when one task does not exist
  ✓ gives the share token of a task

Summary: 4 run, 0 failed, 4 passed in 0ms
```

The ids in the tests come from the file: `add_task` gets the id that PostgreSQL gave in the record run. So the tests check real results, also with no database.

## Step 7: Test a transaction

`complete_tasks` marks a list of tasks as done in one transaction. When one id has no task, the callback returns an `Error`, and the transaction rolls back:

### Complete tasks in one transaction <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/src/app/tasks.gleam#L46-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The test completes a real task and task 999, which does not exist. It expects `TransactionRolledBack`, and the real task still open:

### Test the rollback <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/tasks_tests.gleam#L47-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

In the record run, PostgreSQL rolled back the first `UPDATE`. The recording holds the queries in the transaction and the `SELECT` after it, with task 4 still open:

### The queries of the rollback in the recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recordings/queries/tasks.json#L97-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
    {
      "sql": "UPDATE tasks SET done = true WHERE id = $1",
      "parameters": [4],
      "result": {
        "count": 1,
        "rows": []
      }
    },
    {
      "sql": "UPDATE tasks SET done = true WHERE id = $1",
      "parameters": [999],
      "result": {
        "count": 0,
        "rows": []
      }
    },
    {
      "sql": "SELECT id, title FROM tasks WHERE NOT done ORDER BY id",
      "parameters": [],
      "result": {
        "count": 2,
        "rows": [
          {"tuple":[1,"Buy milk"]},
          {"tuple":[4,"Book flights"]}
        ]
      }
    },
```

How it works:

- The recorder records the queries in the callback of `dream_postgres_client.transaction`. It does not record `BEGIN` and `ROLLBACK`.
- In playback, the callback gets the playback connection. When the callback returns an `Error`, `transaction` gives `TransactionRolledBack` with that error, as it did live.
- The `SELECT` after the rollback gets its recorded rows, so the test sees the state that PostgreSQL really had after the rollback.

## Step 8: Read a query with no recording

In playback mode, a query with no recording never reaches a database. It fails with the query error `InterceptorFailed`. `recorder.error` reads the `recorder.RecorderError` back from that error, and `recorder.describe_error` gives its text. `describe_query_error` of Step 3 does both. Here is a test that asks for the share token of task 42, a query that the record run did not run:

### A test with no recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/miss_tests.gleam#L15-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The test gives the text to `fail_with`, so the report shows each line of the text. The test fails, and the report names the SQL and the parameters. Then it names the nearest recording in the file, and shows its parameters on the `-` line and the parameters of the query on the `+` line:

### The report of a query with no recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/queries_miss.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Tasks
  ✗ finds the share token of task 42
    fail_with
      Message: No recording matches SELECT share_token FROM tasks WHERE id = $1 with [42]
               Nearest recording in test/recordings/queries/tasks.json:
                 parameters:
                 - [5]
                 + [42]
    Run it alone: gleam test -- --only "Tasks/finds the share token of task 42"

Failures:
Tasks
  ✗ finds the share token of task 42
    fail_with
      Message: No recording matches SELECT share_token FROM tasks WHERE id = $1 with [42]
               Nearest recording in test/recordings/queries/tasks.json:
                 parameters:
                 - [5]
                 + [42]
    Run it alone: gleam test -- --only "Tasks/finds the share token of task 42"

Summary: 1 run, 1 failed, 0 passed in 0ms
```

The record run asked for the share token of task 5, so the nearest recording has `[5]`. A nearest recording has the same SQL, as the match key sees it. When no recording in the file has the SQL, the second line is `No recording in <path> has this SQL`.

`recorder.error` gives `Ok(RecorderError)` when the recorder failed the query, and `Error(Nil)` for an error of the database. These are the errors of the recorder:

| Error | When | What to do |
|:---|:---|:---|
| `NoRecording(sql:, parameters:, path:, nearest:)` | Playback: no recording in the file at `path` matches the query. `nearest` holds at most 3 recordings with the same SQL. | Record again, or fix the query. |
| `PlayedAlready(sql:, parameters:, path:)` | Playback: the query ran more times than the file has results for it. | Record again, so the file has a result for each run of the query. |
| `WriteFailed(path:, reason:)` | Record: the recorder could not write the file. The query ran on the database. | Make sure the directory exists and can be written. |
| `NotRecordable(sql:, reason:)` | A parameter or a value of the result is a term that a recording cannot hold, such as a process. | Give the query plain values. |
| `RecorderStopped(sql:)` | The recorder stopped before the query ran. | Stop the recorder in the teardown, after the last test. |

The test runs in playback mode even in a record run, because its setup gives `recorder.Playback`. The main run leaves it out, because it fails on purpose. A test of the project runs it and compares its report with the output above.

## Keep secrets out of the file

You commit the recording file, so it must not hold a secret. Each task has a share token, a secret that PostgreSQL makes at random:

### Read the share token <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/src/app/tasks.gleam#L68-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The secret token of the share link of a task.
pub fn share_token(db: Connection, id: Int) -> Result(String, QueryError) {
  dream_postgres_client.query("SELECT share_token FROM tasks WHERE id = $1")
  |> dream_postgres_client.parameter(dream_postgres_client.int(id))
  |> dream_postgres_client.returning(decode.at([0], decode.string))
  |> dream_postgres_client.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.try(first_row)
}
```

The setup of Step 2 gives the recorder a result transformer. It runs in record mode only, before the recorder writes a result, and puts `[hidden]` in place of each token:

### Hide the share tokens <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/database_setup.gleam#L87-L101"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The file holds `[hidden]`, and never the token:

### The hidden token in the recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recordings/queries/tasks.json#L134-L143"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
    {
      "sql": "SELECT share_token FROM tasks WHERE id = $1",
      "parameters": [5],
      "result": {
        "count": 1,
        "rows": [
          {"tuple":["[hidden]"]}
        ]
      }
    }
```

The test of the token must pass in both modes. A record run gives the real token, and playback gives `[hidden]`. So the test checks only that a token is there:

### Test a hidden value <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/tasks_tests.gleam#L58-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      it("gives the share token of a task", fn(database: Database) {
        use id <- result.try(add(database, "Plan the party"))
        // Playback gives "[hidden]": the recorder never wrote the token
        tasks.share_token(database.db, id)
        |> result.map(string.is_empty)
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("the task should have a share token")
      }),
```

A secret in a parameter, such as a password in an `INSERT`, needs a query transformer. It runs in each mode, before the recorder computes the key, so a query with the real secret still finds its recording. [Step 6 of the dream_postgres guide](https://github.com/TrustBound/dream_postgres/blob/main/docs/guides/recorded-queries.md#step-6-keep-a-secret-out-of-the-file) shows both transformers.

## How a query finds its recording

In playback mode, each query gets the first recording with the same key that it did not get yet. The default key is the SQL and the parameters, character for character. So:

- `open_tasks` runs three times in the suite, with the same SQL and no parameters. It gets its three results in the recorded order.
- Different queries can run in another order than in the record run. Each one gets its own recording.

`recorder.key` sets another key: `recorder.normalized_sql_and_parameters` ignores changes of whitespace in the SQL, `recorder.sql_only` ignores the parameters, and a function of your own can ignore one parameter. The [dream_postgres guide](https://github.com/TrustBound/dream_postgres/blob/main/docs/guides/recorded-queries.md#how-a-query-finds-its-recording) has the table of keys.

## Refresh the recordings

Record again when a query changes, when the schema changes, or when you add a test. The steps:

1. Run `make record` in the project. It starts PostgreSQL, records, and stops PostgreSQL.
2. Read the diff of `test/recordings/queries`. It shows each changed query and result.
3. Run `gleam test` with no variable, to make sure that playback passes.
4. Commit the new file with the change of the code.

Each record run starts from an empty database, because the server keeps no data. So the ids and the rows are the same from run to run. Only values that PostgreSQL makes at random change, such as the share token, and the result transformer hides those.

## Run the tests in CI

CI runs the tests with no `RECORDER_MODE`, so they play back. CI needs no PostgreSQL service and no database URL. The job of the example project runs one script, which [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md#run-the-tests-in-ci) shows in full:

### The CI step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L196-L198"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
      - name: Run the recording tests in playback mode
        working-directory: examples/recording
        run: sh scripts/playback.sh
```

The project proves that playback never connects: its CI job has no database, and the tests pass.

## Common pitfalls

**A query that changed after the record run.** *Symptom:* playback fails with `No recording matches` and the new SQL. When the SQL changed, the second line is `No recording in <path> has this SQL`. When only the parameters changed, the report shows the nearest recording with the old parameters. *Fix:* record again. A change of the schema SQL fails the setup, so each test of the suite shows the error.

**A test that runs a query more often than in the record run.** *Symptom:* `recorder.error` gives `Ok(PlayedAlready(...))`. *Fix:* each recording answers one query. Record again.

**Parallel tests on one table.** *Symptom:* each record run gives other ids, or a test fails in playback that passed in the record run. *Fix:* run the suite with `max_concurrency: 1` through `runner.add_suites_with_config`.

**A secret in a committed recording.** *Symptom:* a token or a password shows in the file. *Fix:* hide it with a result transformer or a query transformer, and record again. Then change the secret, because the history of the repository still holds it.

**A record run that starts from old data.** *Symptom:* the record run finds the rows of an earlier run, and gets other ids. *Fix:* start each record run from an empty database. Stop the server with `docker compose down -v` when the run ends, as the record script does with `trap`, or drop the tables in the setup, as Step 3 does.

**One recorder name for two suites.** *Symptom:* a record run of one suite removes the queries of the other. *Fix:* in record mode, `recorder.start` writes an empty file. Give each suite its own name.

## Where to go next

- [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md): the same pattern for HTTP calls, with `dream_http_client`.
- [Test database code with recorded queries](https://github.com/TrustBound/dream_postgres/blob/main/docs/guides/recorded-queries.md): the full recorder API of `dream_postgres`, and recordings written by hand.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): `runner.add_suites_with_config` and the concurrency of a suite.
- [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md): `context.setup` and the context of each test.
- [API reference on HexDocs](https://hexdocs.pm/dream_postgres/dream_postgres/recorder.html): `recorder` and `recording`.
