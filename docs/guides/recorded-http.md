# Test HTTP calls with recordings

Why this approach: [Mock at the system boundary](https://github.com/TrustBound/dream_test/blob/main/docs/guides/mock-at-the-boundary.md).

A test that calls a real API is slow. It fails when the network is down, when the API has a bad day, or when the API changes its data. Some APIs also cost money for each call. A mock server is fast and stable, but it answers what you told it, not what the API really says. A recording sits between the two. You run the tests one time against the real API, and the HTTP client saves each request and its response to a file. After that, the tests play the files back with no network at all. This guide builds a test suite for a small weather client with the recorder of [dream_http_client](https://github.com/TrustBound/dream_http_client). The suite records with one command, and plays back in CI.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which mode to use](#which-mode-to-use)
- [Step 1: Write code that takes a base request](#step-1-write-code-that-takes-a-base-request)
- [Step 2: Choose the mode from the environment](#step-2-choose-the-mode-from-the-environment)
- [Step 3: Start the recorder in the suite setup](#step-3-start-the-recorder-in-the-suite-setup)
- [Step 4: Write the tests](#step-4-write-the-tests)
- [Step 5: Record one time](#step-5-record-one-time)
- [Step 6: Play back with no network](#step-6-play-back-with-no-network)
- [Step 7: Read a request with no recording](#step-7-read-a-request-with-no-recording)
- [Step 8: Record a stream](#step-8-record-a-stream)
- [Keep secrets and changing data out of the files](#keep-secrets-and-changing-data-out-of-the-files)
- [Run the tests in CI](#run-the-tests-in-ci)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, you will:

- Write a weather client that does not know about recordings.
- Start a recorder in the setup of a suite, and stop it in the teardown.
- Choose the mode with an environment variable: `record` on your machine, playback in CI.
- Record the tests one time, against a mock server that stands in for the real API.
- Play the tests back with no server and no network.
- Read the report of a request that has no recording.
- Record and play back a stream.
- Keep the API token out of the recording files.

## Before you start

You need a project with Dream Test and a test runner. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up. This guide also uses `unit_context.describe` with `context.setup`, which [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md#step-3-get-the-context-from-a-setup) explains.

The code of this guide is the project `examples/recording` in the Dream Test repository. Its tests run in CI on each change. `dream_http_client` and `dream_mock_server` are not on Hex yet, so the project gets them from GitHub. These lines of its `gleam.toml` add the client:

### The HTTP client <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/gleam.toml#L12-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
# Switched to a Hex version range once it is published.
dream_http_client = { git = "https://github.com/TrustBound/dream_http_client.git", ref = "d1382f9660b980ee9c17d3ed097affb911ce42ff" }
```

The tests also need the mock server for the record run, and `envoy` to read an environment variable. These lines are under `[dev-dependencies]`:

### The test dependencies <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/gleam.toml#L20-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
# Switched to a Hex version range once it is published.
dream_mock_server = { git = "https://github.com/TrustBound/dream_mock_server.git", ref = "42f51b21bb89af7cd732dfa6f723dbca67c53672" }
envoy = ">= 1.0.2 and < 2.0.0"
```

The outputs on this page are real outputs of the code shown, with every time set to 0. A test of the project compares each output with the real report.

## Which mode to use

A recorder runs in one of three modes. Each mode is a value of the type `recorder.Mode`, so the compiler rejects a wrong name:

| Your situation | Mode | What the client does |
|:---|:---|:---|
| You want new recordings from the real API | `recorder.Record` | Sends each request, and writes the request and its response to a file before the call returns. |
| The tests must run with no network, as in CI | `recorder.Playback` | Answers each request from a file, and sends nothing. A request with no file fails with `NoRecording`. |
| The recorder is in place, but you want live calls for now | `recorder.Passthrough` | Sends each request, and writes nothing. |

The full API of the recorder is in the guide [Testing with recorded responses](https://github.com/TrustBound/dream_http_client/blob/main/docs/guides/recording-and-playback.md) of `dream_http_client`. This guide shows how to fit it into a Dream Test suite.

## Step 1: Write code that takes a base request

The code under test is a client for a weather API. `forecast` gets the forecast of a city from `GET /v1/forecast/<city>`:

### The weather client <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/src/app/forecast.gleam#L16-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Forecast {
  Forecast(city: String, high: Int, low: Int, summary: String)
}

pub type ForecastError {
  UnknownCity(city: String)
  RequestFailed(reason: String)
  BadBody(reason: String)
}

/// The forecast of a city, from `GET /v1/forecast/<city>`.
pub fn forecast(
  api: ClientRequest,
  city: String,
) -> Result(Forecast, ForecastError) {
  case api |> client.path("/v1/forecast/" <> city) |> client.send() {
    Ok(response) -> decode_forecast(response.body)
    Error(client.ResponseError(response:)) if response.status == 404 ->
      Error(UnknownCity(city))
    Error(client.ResponseError(response:)) ->
      Error(RequestFailed("HTTP " <> int.to_string(response.status)))
    Error(client.RequestError(error:)) ->
      Error(RequestFailed(client.transport_error_to_string(error)))
  }
}

fn decode_forecast(body: BitArray) -> Result(Forecast, ForecastError) {
  let decoder = {
    use city <- decode.field("city", decode.string)
    use high <- decode.field("high", decode.int)
    use low <- decode.field("low", decode.int)
    use summary <- decode.field("summary", decode.string)
    decode.success(Forecast(city:, high:, low:, summary:))
  }
  json.parse_bits(body, decoder)
  |> result.map_error(fn(error) { BadBody(string.inspect(error)) })
}
```

The first parameter is the base request of the API: the scheme, the host, the port and the headers. The function adds only the path. This is the one thing that makes recordings easy. A recorder goes on the base request, so the test gives `forecast` a base request with a recorder, and the code does not change.

## Step 2: Choose the mode from the environment

You record on your machine, and CI plays back. So the mode comes from an environment variable, `RECORDER_MODE`. `recorder.parse_mode` turns the text into a `recorder.Mode`. It accepts `record`, `playback` and `passthrough`, and gives an `Error` that names any other text. With no variable, the tests play back:

### The mode from the environment <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L19-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// What each HTTP test gets: the base request of the API, with a recorder.
pub type Api {
  Api(base: ClientRequest, recorder: Recorder, server: Option(ServerHandle))
}

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no network.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}
```

Playback is the default on purpose. A run that forgets the variable sends nothing to the network. Only a run that asks for `record` can change the files.

`Api` is the context of the tests: the value that each test gets. It holds the base request, the recorder, and the mock server when one runs.

## Step 3: Start the recorder in the suite setup

A recorder is a process. Something must start it before the first test and stop it after the last test. In Dream Test, that is the `setup` and the `teardown` of `context.setup`, which `unit_context.describe` takes. The setup runs one time for the suite, and its value is the context of each test. The teardown gets the same value after the last test. `start_api` is the setup, and `stop_api` is the teardown:

### Start and stop the recorder <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L33-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts a recorder in `mode`. Only a run that sends requests starts the
/// API: playback answers from the files.
pub fn start_api(
  mode: recorder.Mode,
  port: Int,
  start_server: fn(Int) -> Result(ServerHandle, actor.StartError),
) -> Result(Api, String) {
  use server <- result.try(case mode {
    recorder.Playback -> Ok(None)
    recorder.Record | recorder.Passthrough ->
      start_server(port)
      |> result.map(Some)
      |> result.map_error(string.inspect)
  })
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/http")
    |> recorder.mode(mode)
    |> recorder.request_transformer(drop_authorization)
    |> recorder.response_transformer(drop_date)
    |> recorder.start(),
  )
  let base =
    client.new()
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.add_header("Authorization", "Bearer " <> api_token())
    |> client.recorder(recorder)
  Ok(Api(base:, recorder:, server:))
}

pub fn stop_api(api: Api) -> Result(Nil, String) {
  let stopped = recorder.stop(api.recorder)
  option.map(api.server, server.stop)
  stopped
}
```

How it works:

- In record and passthrough mode, the setup starts a mock server with `start_server`. The mock server stands in for the real API, so the record run of this guide needs no internet. With a real API, leave the server out and point the base request at the API.
- In playback mode, nothing starts and nothing listens. The recorder reads each file in `test/recordings/http` when it starts.
- `client.recorder(recorder)` puts the recorder on the base request. Each request that `forecast` makes from it goes through the recorder.
- When the setup returns an `Error`, no test of the suite runs, and the report shows the message. A wrong `RECORDER_MODE` stops the suite there, with the text of `parse_mode`.
- The two transformers keep the token and the `date` header out of the files. [Keep secrets and changing data out of the files](#keep-secrets-and-changing-data-out-of-the-files) shows them.

Why not `before_all` and `after_all` of `dream_test/unit`? Those hooks return `Ok(Nil)`, so they cannot give the recorder to the tests. `context.setup` gives the value of the setup to each test, with its type.

## Step 4: Write the tests

Each test gets the `Api` and passes `api.base` to the code under test:

### A suite that plays back recorded HTTP calls <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/forecast_tests.gleam#L19-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

The tests do not know the mode. The same three tests check the live API in a record run, and the files in a playback run. The third test checks an error status: a 404 response is a recording like any other.

The mock server of the record run has one route for each city, and a 404 for the rest. `server.start_with_config` starts it with these routes only:

### The mock weather API <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/forecast_tests.gleam#L47-L72"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The mock server that stands in for the weather API in a record run.
fn start_mock_weather_api(port: Int) {
  server.start_with_config(port, [
    MockRoute(
      path: "/v1/forecast/oslo",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"city\":\"Oslo\",\"high\":4,\"low\":-2,\"summary\":\"Snow\"}",
    ),
    MockRoute(
      path: "/v1/forecast/lisbon",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"city\":\"Lisbon\",\"high\":19,\"low\":12,\"summary\":\"Sun\"}",
    ),
    MockRoute(
      path: "/v1/forecast/",
      path_match: Prefix,
      method: None,
      status: 404,
      body: "{\"error\":\"unknown city\"}",
    ),
  ])
}
```

The suite runs from the test `main` like any other suite:

### The test main <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recording_test.gleam#L10-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([forecast_tests.tests(), alerts_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [tasks_tests.tests()])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The tests of the HTTP calls can run in parallel: each request has its own file. `tasks_tests` is the suite of [Test database code with recorded queries](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md), and `output_checks` are the tests that compare the outputs of this page.

## Step 5: Record one time

The project has a script that records again. It starts the database for the other guide, and runs the tests with `RECORDER_MODE=record`. It removes no files: a record run replaces the recording of each request that it records again, and keeps the files of the requests that it does not record. So a record run of one test keeps the recordings of the other tests.

### Record the tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/record.sh#L8-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
```

In your own project, the HTTP part is one line: `RECORDER_MODE=record gleam test`. The tests pass as they do in playback, and the recorder writes one file for each request. The name of a file starts with the method, the host and the path. A hash of the match key follows. The name does not depend on the response, so a request keeps its file name in each record run, and `git diff` shows only what changed. This is the file of the Oslo forecast, `GET_localhost__v1_forecast_oslo_e37e6826285e2b49.json`:

### The recording of the Oslo forecast <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/http_oslo_recording.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{"version":"1.0","entries":[{"request":{"method":"GET","scheme":"http","host":"localhost","port":19801,"path":"/v1/forecast/oslo","query":null,"headers":[],"body":""},"response":{"mode":"blocking","status":200,"headers":[["content-type","text/plain; charset=utf-8"],["content-length","50"],["connection","keep-alive"]],"body":"{\"city\":\"Oslo\",\"high\":4,\"low\":-2,\"summary\":\"Snow\"}"}}]}
```

The request has no headers: the request transformer removed the token. The response has no `date` header: the response transformer removed it.

Read each new file before you commit it. A record run accepts whatever the API answered, errors included. Then commit the directory `test/recordings/http` with the tests. The files are part of the tests: without them, playback fails each request.

## Step 6: Play back with no network

Now run `gleam test` with no variable. Nothing listens on port 19801, and the tests pass from the files:

### The report of a playback run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/http_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Forecast
  ✓ gives the forecast for Oslo
  ✓ gives the forecast for Lisbon
  ✓ reports a city that the API does not know
Alert feed
  ✓ reads the message of each alert

Summary: 4 run, 0 failed, 4 passed in 0ms
```

The playback recorder finds the file of each request by its match key. By default, the key is the method and the URL: the scheme, the host, the port, the path and the query. Headers and the body do not count. So the port of the playback run must be the port of the record run. That is why the port is a constant of the suite. [Matching requests and hiding secrets in recordings](https://github.com/TrustBound/dream_http_client/blob/main/docs/guides/request-matching-and-scrubbing.md) shows how to put the body in the key, or to leave parts of the URL out.

## Step 7: Read a request with no recording

In playback mode, a request with no file is not sent. It fails with the transport error `NoRecording`. The error names the method and the URL, and the recordings nearest to the request. A nearest recording has the same method and path, and the error shows each part that differs. Here are two tests with no recording. The first asks for Bergen, a city that the record run did not ask for. The second asks for Oslo on another port:

### Tests with no recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/miss_tests.gleam#L17-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "Forecast",
    context.setup(
      fn() { start_api(recorder.Playback, 19_801, server.start) },
      teardown: stop_api,
    ),
    [
      it("gives the forecast for Bergen", fn(api: Api) {
        forecast(api.base, "bergen") |> have_forecast
      }),
      it("gives the forecast for Oslo on another port", fn(api: Api) {
        forecast(api.base |> client.port(19_802), "oslo") |> have_forecast
      }),
    ],
  )
}

// The failure message is the text of the error, so the report shows each
// line of a miss
fn have_forecast(
  result: Result(Forecast, ForecastError),
) -> Result(AssertionResult, String) {
  case result {
    Ok(_forecast) -> Ok(succeed())
    Error(RequestFailed(reason:)) -> Ok(fail_with(reason))
    Error(error) -> Ok(fail_with(string.inspect(error)))
  }
}
```

`forecast` turns the transport error into text with `client.transport_error_to_string`. `have_forecast` gives that text to `fail_with`, so the report shows each line of the text. The two tests fail:

### The report of requests with no recording <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs/http_miss.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Forecast
  ✗ gives the forecast for Bergen
    fail_with
      Message: No recording matches GET http://localhost:19801/v1/forecast/bergen
No recording in test/recordings/http has this method and path
    Run it alone: gleam test -- --only "Forecast/gives the forecast for Bergen"
  ✗ gives the forecast for Oslo on another port
    fail_with
      Message: No recording matches GET http://localhost:19802/v1/forecast/oslo
Nearest recording: test/recordings/http/GET_localhost__v1_forecast_oslo_e37e6826285e2b49.json
  origin:
  - http://localhost:19801
  + http://localhost:19802
    Run it alone: gleam test -- --only "Forecast/gives the forecast for Oslo on another port"

Failures:
Forecast
  ✗ gives the forecast for Bergen
    fail_with
      Message: No recording matches GET http://localhost:19801/v1/forecast/bergen
No recording in test/recordings/http has this method and path
    Run it alone: gleam test -- --only "Forecast/gives the forecast for Bergen"
  ✗ gives the forecast for Oslo on another port
    fail_with
      Message: No recording matches GET http://localhost:19802/v1/forecast/oslo
Nearest recording: test/recordings/http/GET_localhost__v1_forecast_oslo_e37e6826285e2b49.json
  origin:
  - http://localhost:19801
  + http://localhost:19802
    Run it alone: gleam test -- --only "Forecast/gives the forecast for Oslo on another port"

Summary: 2 run, 2 failed, 0 passed in 0ms
```

The report of Bergen names the directory, because no recording in it has the method and the path. The report of Oslo names the nearest recording. Then it shows the part that differs, with the recorded value on the `-` line and the value of the request on the `+` line. Code that keeps the error as a value gets `RequestError(NoRecording(method, url, directory, nearest))` from `client.send`.

You see this failure in two cases:

1. A new test calls an endpoint that the record run did not call. The report names no nearest recording. Record again.
2. The request changed after the record run, for example with a new query parameter or another port. The report shows the part that changed. Record again, or fix the request.

The tests run in playback mode even in a record run, because their setup gives `recorder.Playback`. The main run leaves them out, because they fail on purpose. A test of the project runs them and compares their report with the output above.

## Step 8: Record a stream

The recorder also records streams, from `stream_yielder`, `start_stream` and `stream_to`. It keeps each chunk, and the time since the chunk before it. Here is a function that reads a feed of weather alerts, one JSON object for each line:

### Read the messages of an alert feed <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/src/app/forecast.gleam#L54-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The message of each alert in the feed at `GET /stream/json`, which
/// sends one JSON object for each line, as the alerts happen.
pub fn alert_messages(api: ClientRequest) -> Result(List(String), String) {
  use chunks <- result.try(
    api
    |> client.path("/stream/json")
    |> client.stream_yielder()
    |> yielder.to_list()
    |> result.all()
    |> result.map_error(string.inspect),
  )
  // A line can arrive in two chunks, so join the chunks before the split
  use text <- result.try(
    chunks
    |> list.map(bytes_tree.to_bit_array)
    |> bit_array.concat
    |> bit_array.to_string
    |> result.replace_error("The feed is not UTF-8 text"),
  )
  text
  |> string.split("\n")
  |> list.filter(fn(line) { line != "" })
  |> list.try_map(fn(line) {
    json.parse(line, decode.at(["message"], decode.string))
    |> result.map_error(string.inspect)
  })
}
```

The suite has the same form as the forecast suite. Its setup starts the built-in endpoints of the mock server in a record run, with `server.start`. The endpoint `/stream/json` sends five JSON lines, one every 200 ms:

### A suite that plays back a stream <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/alerts_tests.gleam#L14-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("Alert feed", context.setup(start_alert_feed, teardown: stop_api), [
    it("reads the message of each alert", fn(api: Api) {
      alert_messages(api.base)
      |> should
      |> be_equal(
        Ok([
          "JSON event 1", "JSON event 2", "JSON event 3", "JSON event 4",
          "JSON event 5",
        ]),
      )
      |> or_fail_with("the feed should give five alerts in order")
    }),
  ])
}

// The built-in endpoints of the mock server include /stream/json, which
// sends five JSON lines, one every 200 ms.
fn start_alert_feed() -> Result(Api, String) {
  use mode <- result.try(recorder_mode())
  start_api(mode, alerts_port, server.start)
}
```

Know what playback of a stream does:

- It gives the recorded chunks with the same boundaries.
- It waits the recorded time before each chunk. So this test takes about 800 ms in playback too. The timeout of the request applies as it does live.
- A record run writes the times again. The file keeps its name, and the record run replaces its content, so `git diff` shows the new times. Commit them, or restore the file if only the times changed.

[Streaming a response](https://github.com/TrustBound/dream_http_client/blob/main/docs/guides/streaming.md#test-your-streaming-code) of `dream_http_client` shows how to write a stream recording by hand, for example one that cuts a line in two.

## Keep secrets and changing data out of the files

You commit the recording files, so they must not hold a secret. The base request of Step 3 has an `Authorization` header with the API token. A request transformer removes it:

### Remove the token from each request <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/recorded_http/api_setup.gleam#L71-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// A record run against the real API needs a real token. Playback sends
// nothing, so any text works.
fn api_token() -> String {
  envoy.get("WEATHER_API_TOKEN") |> result.unwrap("test-token")
}

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

The request transformer runs in each mode, before the recorder computes the key. So the file never holds the token, and a playback request with any token still finds its file.

A response transformer runs in record mode only, before the recorder writes the response. Use it for secrets in responses, such as a `set-cookie` header, and for data that changes on each run. The `date` header changes on each run, so each record run would change the file of a request whose response is the same. Without the header, the file stays the same:

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

A test makes sure that no file holds the token. It reads all the files, and fails if one of them holds `authorization` or the token:

### Make sure that no recording holds the token <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/test/outputs_tests.gleam#L44-L53"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("keeps the token out of the HTTP recordings", fn() {
      use text <- result.try(all_http_recordings())
      #(
        string.contains(string.lowercase(text), "authorization"),
        string.contains(text, "test-token"),
      )
      |> should
      |> be_equal(#(False, False))
      |> or_fail_with("no HTTP recording should hold the token")
    }),
```

## Run the tests in CI

CI runs the tests with no `RECORDER_MODE`, so they play back. It needs no network, no API token and no server. This is the CI job of the example project:

### The CI job <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L176-L198"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
  recording:
    name: Recording tests in playback mode
    # The tests of the guides about recorded HTTP calls and recorded queries
    # play back the recordings in examples/recording/test/recordings. They
    # need no network and no database, so this job has no PostgreSQL
    # service. The tests also compare the outputs that the guides show.
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Erlang and Gleam
        uses: erlef/setup-beam@v1
        with:
          otp-version: "28"
          gleam-version: "1.19.2"
          # The PostgreSQL driver of dream_postgres builds with rebar3
          rebar3-version: "3"

      - name: Run the recording tests in playback mode
        working-directory: examples/recording
        run: sh scripts/playback.sh
```

The script runs the format check and the tests:

### The playback script <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/playback.sh#L6-L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam format --check
gleam test
```

To refresh the recordings, a developer runs the record script on their machine, reads the diff of `test/recordings`, and commits it. The diff of the pull request shows the reviewer exactly what the API answers now.

## Common pitfalls

**A recording that is not committed.** *Symptom:* the tests pass on your machine, and fail in CI with `No recording matches` and `has this method and path`. *Fix:* commit the directory of the recordings with the tests.

**Two files for one request.** *Symptom:* playback fails with `Ambiguous recording match` for a request. *Fix:* a record run replaces the files of each request that it records, so the second file came from somewhere else, such as a file written by hand or copied in. Remove one of the files, or record that request again.

**A different port in playback.** *Symptom:* `No recording matches`, and the nearest recording shows an `origin` with another port. *Fix:* the default key holds the port. Keep the port of the tests in a constant, and use it in both modes.

**A token in a recording.** *Symptom:* the API token shows in a file in your repository. *Fix:* remove the header with a request transformer, and add a test that reads the files. Then change the token, because the history of the repository still holds it.

**A setup that uses the wrong hooks.** *Symptom:* the tests cannot get the recorder, or each test starts its own. *Fix:* start the recorder in the `setup` function of `context.setup`, and stop it in the `teardown`. Each test then gets it in its context.

**A test that passes only against the live API.** *Symptom:* a test passes in a record run and fails in playback, or the other way. *Fix:* the test depends on something that changes on each run, such as the current time. Check only the stable parts, or remove the changing data with a response transformer.

## Where to go next

- [Test database code with recorded queries](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md): the same pattern for PostgreSQL queries, with `dream_postgres`.
- [Testing with recorded responses](https://github.com/TrustBound/dream_http_client/blob/main/docs/guides/recording-and-playback.md): the full recorder API of `dream_http_client`, and recordings written by hand.
- [Matching requests and hiding secrets in recordings](https://github.com/TrustBound/dream_http_client/blob/main/docs/guides/request-matching-and-scrubbing.md): match keys, and what to do when two recordings match.
- [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md): `context.setup` and the context of each test.
- [dream_mock_server](https://github.com/TrustBound/dream_mock_server): the mock server of the record run.
