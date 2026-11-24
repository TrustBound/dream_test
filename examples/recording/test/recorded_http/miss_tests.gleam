//// A test with no recording, for the guide "Test HTTP calls with
//// recordings". It fails on purpose, so the main run does not run it:
//// `outputs_tests` runs it and compares its report.

import app/forecast.{forecast}
import dream_http_client/recorder
import dream_mock_server/server
import dream_test/context
import dream_test/matchers.{be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
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
        forecast(api.base, "bergen")
        |> should
        |> be_ok()
        |> or_fail_with("Bergen should have a forecast")
      }),
    ],
  )
}
