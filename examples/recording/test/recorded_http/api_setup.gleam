//// The setup and the teardown of the HTTP suites: a recorder, and in
//// record mode a mock server that stands in for the real API.

import dream_http_client/client.{type ClientRequest}
import dream_http_client/recorder.{type Recorder}
import dream_http_client/recording.{
  type RecordedRequest, type RecordedResponse, BlockingResponse, RecordedRequest,
  StreamingResponse,
}
import dream_mock_server/server.{type ServerHandle}
import envoy
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

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
