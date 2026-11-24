# Mock at the system boundary

Keep the application code and the test assertions. Change what answers at the dependency boundary.

This guide explains the idea behind the two recording guides of Dream Test. It is not a list of steps. Each code block and each output is from the project `examples/recording` in the Dream Test repository, and a test of that project compares each output with the real report, with the times left out.

## Table of Contents

- [What changed our mind](#what-changed-our-mind)
- [Two boundaries](#two-boundaries)
- [Keep substitution in the suite setup](#keep-substitution-in-the-suite-setup)
- [Use recordings to capture behavior and make it repeatable](#use-recordings-to-capture-behavior-and-make-it-repeatable)
- [Scrub before anything is written](#scrub-before-anything-is-written)
- [Keep the scenario as you widen the scope](#keep-the-scenario-as-you-widen-the-scope)
- [Catch changes in external systems before deployment](#catch-changes-in-external-systems-before-deployment)
- [Be clear about where recordings can drift](#be-clear-about-where-recordings-can-drift)
- [The two working examples](#the-two-working-examples)

## What changed our mind

Every test that touches an outside service forces a choice. Call the real service, and the test is slow, needs a network and credentials, and fails when the service has a bad day. Replace the service, and you must decide where the replacement goes.

Over twenty years of engineering, we tried most of the usual answers. Hand-written fixtures go stale: they hold the response we expected, not the response the service sends. Dependency injection works, but it spreads. Every function between the test and the service gets a parameter that exists only so that a test can pass a fake through it.

What changed our mind was a smaller seam. The code under test takes one value that leads outside the system: a base HTTP request, or a database connection. In a test, a recorder supplies that value. Everything between the public entry point and that value runs for real, and nothing in the application knows that a test runs. The same suite runs against the live service when we want to check the service, and from recordings when we want speed. A playback run takes milliseconds and needs no network and no database.

Here is one suite of the example project. It tests a weather client, and it runs both ways:

### The Forecast suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/forecast_tests.gleam#L19-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("Forecast", context.setup(start_weather_api, teardown: stop_api), [
    it("gives the forecast for Oslo", fn(api: Api) {
      forecast(api.base, "oslo")
      |> should
      |> be_equal(Ok(Forecast("Oslo", high: 4, low: -2, summary: "Snow")))
      |> or_fail_with("the forecast for Oslo should be snow")
    }),
    it("gives the forecast for Lisbon", fn(api: Api) {
      forecast(api.base, "lisbon")
      |> should
      |> be_equal(Ok(Forecast("Lisbon", high: 19, low: 12, summary: "Sun")))
      |> or_fail_with("the forecast for Lisbon should be sun")
    }),
    it("reports a city that the API does not know", fn(api: Api) {
      forecast(api.base, "atlantis")
      |> should
      |> be_equal(Error(UnknownCity("atlantis")))
      |> or_fail_with("Atlantis should be unknown")
    }),
  ])
}

fn start_weather_api() -> Result(Api, String) {
  use mode <- result.try(recorder_mode())
  start_api(mode, weather_port, start_mock_weather_api)
}
```

The live run sends each request to the API. In the example project, a mock server stands in for the API, and PostgreSQL runs in Docker:

### Run the tests live <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/live.sh#L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
RECORDER_MODE=passthrough gleam test
```

### The Forecast suite in a live run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/forecast_live.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Forecast
  ✓ gives the forecast for Oslo (43ms)
  ✓ gives the forecast for Lisbon (43ms)
  ✓ reports a city that the API does not know (41ms)

Summary: 3 run, 0 failed, 3 passed in 127ms
```

The offline run sends nothing. The recorder answers each request from a file:

### Run the tests offline <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/playback.sh#L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam test
```

### The Forecast suite in an offline run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/forecast_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Forecast
  ✓ gives the forecast for Oslo (2ms)
  ✓ gives the forecast for Lisbon (2ms)
  ✓ reports a city that the API does not know (2ms)

Summary: 3 run, 0 failed, 3 passed in 6ms
```

The two reports are the same, except for the times. The tests, the assertions and the weather client are the same in both runs. Only the environment variable is different. The outputs show the Forecast suite of each run, with the times of one real run of each mode. Measured on an Apple M1 Max, 64 GB, macOS 26.5.1, 2026-11-24. The times are different for each run and each machine. A test of the project runs the Forecast suite in each mode and compares its report with these outputs, with the times left out.

## Two boundaries

A test of this kind has two boundaries.

1. **The public interface.** The test drives the system through the functions that a caller uses. It checks a result that a caller can see.
2. **The dependency boundary.** The test controls the outbound HTTP calls or database queries. A recorder catches each call at the point where it leaves the system.

This is black-box testing with one more control. The test does not look inside the box, and it does not replace parts inside the box. It controls the world around the box. Here is a test of the database example. It adds a task through the public function, and checks the open tasks that a caller gets:

### A test through the public interface <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/tasks_tests.gleam#L20-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
```

The test does not know how `open_tasks` builds its query. It knows only what the function gives back.

## Keep substitution in the suite setup

The real code takes one value at its boundary. The weather client takes a base HTTP request. The task functions take a database connection. The suite setup of Dream Test (`context.setup`) makes that value, and gives it to each test. The setup also chooses the mode: record, playback or passthrough.

The HTTP setup puts a recorder on the base request:

### A base request with a recorder <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L55-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let base =
    client.new()
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.add_header("Authorization", "Bearer " <> api_token())
    |> client.recorder(recorder)
  Ok(Api(base:, recorder:, server:))
```

The database setup gets the connection from a recorder:

### A connection from a recorder <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_queries/database_setup.gleam#L36-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

This keeps the useful seam of dependency injection: the code gets its dependency as a value. But there is only one seam for each dependency, at the edge of the system. The application does not need a mock for each internal collaborator, and the internal code does not pass mocks from function to function.

## Use recordings to capture behavior and make it repeatable

A hand-written fixture holds what its author expected. A real dependency gives what it really does: the full shape of each response, the headers, the status codes and the errors. A recording keeps all of that. This is the recorded response of the Oslo forecast:

### The recording of the Oslo forecast <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/http_oslo_recording.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{"version":"1.0","entries":[{"request":{"method":"GET","scheme":"http","host":"localhost","port":19801,"path":"/v1/forecast/oslo","query":null,"headers":[],"body":""},"response":{"mode":"blocking","status":200,"headers":[["content-type","text/plain; charset=utf-8"],["content-length","50"],["connection","keep-alive"]],"body":"{\"city\":\"Oslo\",\"high\":4,\"low\":-2,\"summary\":\"Snow\"}"}}]}
```

The file holds three headers that the server added and the test never wrote. A fixture written by hand often leaves such details out.

Playback makes the run repeatable. It is fast, it needs no network and no database, and it gives the same answers each time. A request or a query with no recording fails. The report names it, and shows the nearest recording and the parts that differ. So a test cannot pass by accident against a missing recording.

A fixture server still has a place. It can give a rare case on purpose, such as an error that the real service gives only rarely. The HTTP guide records a local fixture server, a mock server with fixed routes. The database guide records a real PostgreSQL server in Docker.

## Scrub before anything is written

You commit the recordings, so they must not hold a secret. They also must not hold data that changes on each run, or each record run changes the files. Transformers change each request, response or result before the recorder writes it.

A request transformer removes the authorization header:

### Remove the token from each request <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L77-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Runs on each request before the recorder saves it or looks it up, so
/// the token never reaches a file.
pub fn drop_authorization(request: RecordedRequest) -> RecordedRequest {
  RecordedRequest(
    ..request,
    headers: list.filter(request.headers, fn(header) {
      string.lowercase(header.0) != "authorization"
    }),
  )
}
```

A response transformer removes the `date` header, which changes on each run:

### Remove the date from each response <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L88-L105"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Runs on each response in record mode only, before the recorder saves
/// it. The date header changes on each run. Without it, a new recording of
/// the same response gives the same file.
pub fn drop_date(
  _request: RecordedRequest,
  response: RecordedResponse,
) -> RecordedResponse {
  case response {
    BlockingResponse(status:, headers:, body:) ->
      BlockingResponse(status:, headers: without_date(headers), body:)
    StreamingResponse(status:, headers:, chunks:) ->
      StreamingResponse(status:, headers: without_date(headers), chunks:)
  }
}

fn without_date(headers: List(#(String, String))) -> List(#(String, String)) {
  list.filter(headers, fn(header) { string.lowercase(header.0) != "date" })
}
```

A result transformer puts `[hidden]` in place of each share token that the database gives:

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

Choose what to remove and what to replace. Keep the values and the relations that the tests depend on. The transformer above replaces the token and keeps the row, so the test can still check that a token is there. The ids stay, so the tests can still find their tasks. Then read each new file before you commit it.

## Keep the scenario as you widen the scope

One scenario can run at more than one scope. Each scope proves something different:

| Run | What answers at the boundary | What the run proves |
|:---|:---|:---|
| Offline, in playback | The recordings | The code handles the captured behavior. This run gives quick feedback. |
| With a real database | PostgreSQL | Transactions and persistence work on a real server. |
| With a live service or a sandbox | The service | The code agrees with the current contract of the service. |

The suite in [What changed our mind](#what-changed-our-mind) shows this. The same tests ran live and offline, and only the environment variable changed. Where the entry points of a system allow it, the same business expectation can also carry across unit, integration, system and end-to-end runs. The expectation stays, and only the boundary changes.

## Catch changes in external systems before deployment

We did a lot of work with integrations. Those integrations changed small things without warning, and we found out in production. Then we put a system test in CI that ran our tests against the real system. With it, we found these changes before deployment.

The same suite does this job. Normal CI runs in playback, with no network and no database. A second CI job runs the same tests against the real system, on a schedule or before each deployment. It sets the variable that the example suites read:

- `RECORDER_MODE=passthrough gleam test` sends each request and query to the real system, and writes nothing.
- `RECORDER_MODE=record gleam test` also writes new recordings. Use it when you want a diff of what changed.

When the system changes a field, a status or the shape of an error, a test of that job fails before the deployment. The script of the live run in [What changed our mind](#what-changed-our-mind) is such a run for the example project. The example project has no CI job of this kind. Its CI job runs in playback only.

## Be clear about where recordings can drift

A recording is a copy of one moment. Know what each run proves:

- A playback run that passes proves how your code handles the captured interaction. It does not prove that the dependency still behaves that way.
- A live run checks whether the dependency still behaves that way.
- A harmless change to your own SQL or to an HTTP request can also need a new recording. The recorder finds a recording by a match key, such as the method and the URL, or the SQL and its parameters. When the key changes, playback finds no recording and the test fails, also when the behavior is the same. The report shows the nearest recording and the part that changed, so you see which change it was.

So run the live suite at times, and record again when the code or the dependency changes.

## The two working examples

- [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md): record the calls of an API client one time, play them back in CI with no network, and keep the token out of the files.
- [Test database code with recorded queries](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md): record PostgreSQL queries one time, play them back with no database, and test a transaction.
