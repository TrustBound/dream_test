//// Tests with no recording, for the guide "Test HTTP calls with
//// recordings". They fail on purpose, so the main run does not run them:
//// `outputs_tests` runs them and compares their report.

import app/forecast.{type Forecast, type ForecastError, RequestFailed, forecast}
import dream_http_client/client
import dream_http_client/recorder
import dream_mock_server/server
import dream_test/context
import dream_test/matchers.{fail_with, succeed}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}
import gleam/string
import recorded_http/api_setup.{type Api, start_api, stop_api}

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
