//// The streaming suite of the guide "Test HTTP calls with recordings".

import app/forecast.{alert_messages}
import dream_mock_server/server
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import recorded_http/api_setup.{type Api, recorder_mode, start_api, stop_api}

const alerts_port = 19_802

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
