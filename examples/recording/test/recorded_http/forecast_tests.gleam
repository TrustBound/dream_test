//// The forecast suite of the guide "Test HTTP calls with recordings".

import app/forecast.{Forecast, UnknownCity, forecast}
import dream_mock_server/config.{Exact, MockRoute, Prefix}
import dream_mock_server/server
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/http
import gleam/option.{None, Some}
import gleam/result
import recorded_http/api_setup.{type Api, recorder_mode, start_api, stop_api}

/// The port of the weather API in the tests. The recordings hold it, so
/// playback must use the same port.
const weather_port = 19_801

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
