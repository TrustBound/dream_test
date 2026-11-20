import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, group, it}
import fixtures/test_results.{report_of, report_with_cleanup_failure}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

@external(erlang, "dream_test_reporter_test_ffi", "without_gleam_stdlib_application")
fn without_gleam_stdlib_application(function: fn() -> a) -> a

fn result_of(
  name: String,
  status: types.Status,
  failures: List(types.AssertionFailure),
  kind: types.TestKind,
) -> types.TestResult {
  types.TestResult(
    name: name,
    groups: ["s"],
    status: status,
    duration_ms: 2,
    tags: [],
    failures: failures,
    kind: kind,
  )
}

fn failure(payload: types.FailurePayload) -> types.AssertionFailure {
  types.AssertionFailure(
    operator: "check",
    message: "m",
    payload: Some(payload),
  )
}

/// One test of each status and kind.
fn every_status() -> List(types.TestResult) {
  [
    result_of("passes", types.Passed, [], types.Unit),
    result_of(
      "fails",
      types.Failed,
      [types.AssertionFailure(operator: "check", message: "m", payload: None)],
      types.Unit,
    ),
    result_of(
      "skips",
      types.Skipped,
      [],
      types.GherkinScenario(scenario_id: "f:1", rule: None),
    ),
    result_of("waits", types.Pending, [], types.Unit),
    result_of("times out", types.TimedOut, [], types.Unit),
    result_of("has no setup", types.SetupFailed, [], types.Unit),
  ]
}

/// One failure of each payload.
fn every_payload() -> List(types.AssertionFailure) {
  [
    failure(types.EqualityFailure(actual: "1", expected: "2")),
    failure(types.BooleanFailure(actual: True, expected: False)),
    failure(types.OptionFailure(actual: "None", expected_some: True)),
    failure(types.ResultFailure(actual: "Ok(1)", expected_ok: False)),
    failure(types.CollectionFailure(
      actual: "[1]",
      expected: "2",
      operation: "contain",
    )),
    failure(types.ComparisonFailure(actual: "1", expected: "2", operator: ">")),
    failure(types.StringMatchFailure(
      actual: "abc",
      pattern: "x",
      operation: "start_with",
    )),
    failure(types.SnapshotFailure(
      actual: "new",
      expected: "old",
      snapshot_path: "a.snap",
      is_missing: False,
    )),
    failure(types.CustomMatcherFailure(actual: "7", description: "is even")),
  ]
}

/// The text after a marker. The report starts with a timestamp and the
/// system data, so the tests compare only the fixed part after them.
fn after(text: String, marker: String) -> String {
  case string.split_once(text, marker) {
    Ok(#(_before, rest)) -> rest
    Error(Nil) -> ""
  }
}

/// The text between two markers.
fn between(text: String, start: String, end: String) -> String {
  case string.split_once(after(text, start), end) {
    Ok(#(inside, _rest)) -> inside
    Error(Nil) -> ""
  }
}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "t1",
      groups: ["suite"],
      status: types.Passed,
      duration_ms: 1,
      tags: ["tag"],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("dream_test/reporters/json", [
    it("format emits JSON containing the test name", fn() {
      let out = json.format(report_of(sample_results()))
      case string.contains(out, "\"t1\"") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "json.format",
              message: "expected JSON output to include the test name",
              payload: None,
            )),
          )
      }
    }),

    it("format_pretty emits JSON containing the test name", fn() {
      let out = json.format_pretty(report_of(sample_results()))
      case string.contains(out, "\"t1\"") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "json.format_pretty",
              message: "expected JSON output to include the test name",
              payload: None,
            )),
          )
      }
    }),

    it("report and report_pretty do not crash", fn() {
      let write = fn(_s: String) { Nil }
      json.report(report_of(sample_results()), write)
      json.report_pretty(report_of(sample_results()), write)
      Ok(types.AssertionOk)
    }),

    group("builders", [
      it("pretty turns on pretty output", fn() {
        json.new()
        |> json.pretty()
        |> should
        |> be_equal(
          reporter_types.Json(reporter_types.JsonReporterConfig(pretty: True)),
        )
        |> or_fail_with("pretty should set pretty to True")
      }),

      it("pretty leaves a BDD reporter as it is", fn() {
        bdd.new()
        |> json.pretty()
        |> should
        |> be_equal(bdd.new())
        |> or_fail_with("pretty should change only a JSON reporter")
      }),
    ]),

    group("render", [
      it("writes compact JSON when pretty is off", fn() {
        json.render(
          reporter_types.JsonReporterConfig(pretty: False),
          report_of([
            result_of("passes", types.Passed, [], types.Unit),
          ]),
        )
        |> after("\"summary\":")
        |> should
        |> be_equal(
          "{\"total\":1,\"passed\":1,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":0,\"setup_stopped\":0},\"tests\":[{\"name\":\"passes\",\"full_name\":[\"s\",\"passes\"],\"status\":\"passed\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[]}],\"hook_failures\":[]}\n",
        )
        |> or_fail_with("compact JSON should have no spaces or new lines")
      }),

      it("writes indented JSON when pretty is on", fn() {
        json.render(
          reporter_types.JsonReporterConfig(pretty: True),
          report_of([
            result_of("passes", types.Passed, [], types.Unit),
          ]),
        )
        |> after("\"summary\": ")
        |> should
        |> be_equal(
          "{\n"
          <> "    \"total\": 1,\n"
          <> "    \"passed\": 1,\n"
          <> "    \"failed\": 0,\n"
          <> "    \"skipped\": 0,\n"
          <> "    \"pending\": 0,\n"
          <> "    \"timed_out\": 0,\n"
          <> "    \"setup_failed\": 0,\n"
          <> "    \"teardown_failed\": 0,\n"
          <> "    \"setup_stopped\": 0\n"
          <> "  },\n"
          <> "  \"tests\": [\n"
          <> "    {\n"
          <> "      \"name\": \"passes\",\n"
          <> "      \"full_name\": [\n"
          <> "        \"s\",\n"
          <> "        \"passes\"\n"
          <> "      ],\n"
          <> "      \"status\": \"passed\",\n"
          <> "      \"duration_ms\": 2,\n"
          <> "      \"tags\": [],\n"
          <> "      \"kind\": \"unit\",\n"
          <> "      \"failures\": []\n"
          <> "    }\n"
          <> "  ],\n"
          <> "  \"hook_failures\": []\n"
          <> "}\n",
        )
        |> or_fail_with("pretty JSON should have one field on each line")
      }),
    ]),

    group("format", [
      it("writes schema version 2.0", fn() {
        json.format(report_of([]))
        |> between("\"version\":", ",")
        |> should
        |> be_equal("\"2.0\"")
        |> or_fail_with("the schema version should be 2.0")
      }),

      it("counts the teardown failures in the summary", fn() {
        json.format(report_with_cleanup_failure([]))
        |> between("\"summary\":", ",\"tests\"")
        |> should
        |> be_equal(
          "{\"total\":0,\"passed\":0,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":1,\"setup_stopped\":0}",
        )
        |> or_fail_with("the summary should count the teardown failures")
      }),

      it("counts stopped setups apart from failed teardown hooks", fn() {
        types.run_report(
          tests: [],
          hook_failures: [
            types.SetupStopped(
              setup: types.BeforeAllHook,
              path: ["root"],
              reason: "Boom",
              not_run: [],
            ),
          ],
          reporter_crashes: [],
        )
        |> json.format
        |> between("\"summary\":", ",\"tests\"")
        |> should
        |> be_equal(
          "{\"total\":0,\"passed\":0,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":0,\"setup_stopped\":1}",
        )
        |> or_fail_with("a stopped setup should have its own count")
      }),

      it("writes every teardown failure after the tests", fn() {
        json.format(report_with_cleanup_failure([]))
        |> after("\"tests\":")
        |> should
        |> be_equal(
          "[],\"hook_failures\":[{\"kind\":\"teardown_failed\",\"hook\":\"after_all\",\"path\":[\"root\"],\"message\":\"no cleanup\"}]}\n",
        )
        |> or_fail_with(
          "each teardown failure should have its kind, hook, scope and message",
        )
      }),

      it("writes a stopped setup with its setup hook and reason", fn() {
        types.run_report(
          tests: [],
          hook_failures: [
            types.SetupStopped(
              setup: types.BeforeAllHook,
              path: ["root"],
              reason: "Boom",
              not_run: [["root", "b"], ["root", "c"]],
            ),
          ],
          reporter_crashes: [],
        )
        |> json.format
        |> after("\"tests\":")
        |> should
        |> be_equal(
          "[],\"hook_failures\":[{\"kind\":\"setup_stopped\",\"hook\":\"before_all\",\"path\":[\"root\"],\"message\":\"Boom\",\"not_run\":[[\"root\",\"b\"],[\"root\",\"c\"]]}]}\n",
        )
        |> or_fail_with("a stopped setup should have its own kind")
      }),

      it("counts every status in the summary", fn() {
        json.format(report_of(every_status()))
        |> between("\"summary\":", ",\"tests\"")
        |> should
        |> be_equal(
          "{\"total\":6,\"passed\":1,\"failed\":1,\"skipped\":1,\"pending\":1,\"timed_out\":1,\"setup_failed\":1,\"teardown_failed\":0,\"setup_stopped\":0}",
        )
        |> or_fail_with("the summary should count each status")
      }),

      it("writes the Rule of a Gherkin scenario inside a Rule", fn() {
        json.format(
          report_of([
            result_of(
              "sells",
              types.Passed,
              [],
              types.GherkinScenario(
                scenario_id: "F::Rule: Stock::sells#1",
                rule: Some("Rule: Stock"),
              ),
            ),
          ]),
        )
        |> after("\"tests\":")
        |> should
        |> be_equal(
          "[{\"name\":\"sells\",\"full_name\":[\"s\",\"sells\"],\"status\":\"passed\",\"duration_ms\":2,\"tags\":[],\"kind\":\"gherkin:F::Rule: Stock::sells#1\",\"rule\":\"Rule: Stock\",\"failures\":[]}],\"hook_failures\":[]}\n",
        )
        |> or_fail_with("a Gherkin scenario should have its Rule")
      }),

      it("writes the status and kind of every test", fn() {
        json.format(report_of(every_status()))
        |> after("\"tests\":")
        |> should
        |> be_equal(
          "[{\"name\":\"passes\",\"full_name\":[\"s\",\"passes\"],\"status\":\"passed\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[]},{\"name\":\"fails\",\"full_name\":[\"s\",\"fails\"],\"status\":\"failed\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[{\"operator\":\"check\",\"message\":\"m\"}]},{\"name\":\"skips\",\"full_name\":[\"s\",\"skips\"],\"status\":\"skipped\",\"duration_ms\":2,\"tags\":[],\"kind\":\"gherkin:f:1\",\"rule\":null,\"failures\":[]},{\"name\":\"waits\",\"full_name\":[\"s\",\"waits\"],\"status\":\"pending\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[]},{\"name\":\"times out\",\"full_name\":[\"s\",\"times out\"],\"status\":\"timed_out\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[]},{\"name\":\"has no setup\",\"full_name\":[\"s\",\"has no setup\"],\"status\":\"setup_failed\",\"duration_ms\":2,\"tags\":[],\"kind\":\"unit\",\"failures\":[]}],\"hook_failures\":[]}\n",
        )
        |> or_fail_with("each test should have its status and kind")
      }),

      it("writes the fields of every failure payload", fn() {
        json.format(
          report_of([
            result_of("payloads", types.Failed, every_payload(), types.Unit),
          ]),
        )
        |> after("\"failures\":")
        |> should
        |> be_equal(
          "[{\"operator\":\"check\",\"message\":\"m\",\"expected\":\"2\",\"actual\":\"1\"},{\"operator\":\"check\",\"message\":\"m\",\"expected\":false,\"actual\":true},{\"operator\":\"check\",\"message\":\"m\",\"expected_some\":true,\"actual\":\"None\"},{\"operator\":\"check\",\"message\":\"m\",\"expected_ok\":false,\"actual\":\"Ok(1)\"},{\"operator\":\"check\",\"message\":\"m\",\"expected\":\"2\",\"actual\":\"[1]\",\"operation\":\"contain\"},{\"operator\":\"check\",\"message\":\"m\",\"expected\":\"2\",\"actual\":\"1\",\"comparison_operator\":\">\"},{\"operator\":\"check\",\"message\":\"m\",\"pattern\":\"x\",\"actual\":\"abc\",\"operation\":\"start_with\"},{\"operator\":\"check\",\"message\":\"m\",\"expected\":\"old\",\"actual\":\"new\",\"snapshot_path\":\"a.snap\",\"is_missing\":false},{\"operator\":\"check\",\"message\":\"m\",\"actual\":\"7\",\"description\":\"is even\"}]}],\"hook_failures\":[]}\n",
        )
        |> or_fail_with("each payload should have its own fields")
      }),

      it("keeps escaped characters in pretty output", fn() {
        json.format_pretty(
          report_of([
            result_of("say \"hi\"\n{a, b}: [c]", types.Passed, [], types.Unit),
          ]),
        )
        |> between("\"name\": ", ",\n")
        |> should
        |> be_equal("\"say \\\"hi\\\"\\n{a, b}: [c]\"")
        |> or_fail_with("characters in a string should not change the layout")
      }),

      it(
        "keeps a string that starts with a combining mark in pretty output",
        fn() {
          json.format_pretty(
            report_of([
              result_of("\u{0301}a, b", types.Passed, [], types.Unit),
            ]),
          )
          |> between("\"name\": ", ",\n")
          |> should
          |> be_equal("\"\u{0301}a, b\"")
          |> or_fail_with("a combining mark should not join the quote")
        },
      ),

      it(
        "writes unknown as the gleam_stdlib version without the gleam_stdlib application",
        fn() {
          without_gleam_stdlib_application(fn() { json.format(report_of([])) })
          |> between("\"gleam_stdlib_version\":", "}")
          |> should
          |> be_equal("\"unknown\"")
          |> or_fail_with("the gleam_stdlib version should be unknown")
        },
      ),

      it("names the system fields for what they report", fn() {
        json.format(report_of([]))
        |> between("\"system\":{", "}")
        |> remove_values
        |> should
        |> be_equal("\"os\",\"otp_version\",\"gleam_stdlib_version\"")
        |> or_fail_with("expected os, otp_version and gleam_stdlib_version")
      }),

      it("ends the compact report with a newline", fn() {
        json.format(report_of([]))
        |> string.ends_with("}\n")
        |> should
        |> be_equal(True)
        |> or_fail_with("the compact report should end with a newline")
      }),

      it("ends the pretty report with a newline", fn() {
        json.format_pretty(report_of([]))
        |> string.ends_with("\n}\n")
        |> should
        |> be_equal(True)
        |> or_fail_with("the pretty report should end with a newline")
      }),

      it("has one newline only, at the end of the compact report", fn() {
        json.format(report_of(sample_results()))
        |> string.split("\n")
        |> list.length
        |> should
        |> be_equal(2)
        |> or_fail_with("the compact report should be one line")
      }),
    ]),
  ])
}

/// The field names of a flat JSON object body, without their values.
fn remove_values(object_body: String) -> String {
  object_body
  |> string.split(",")
  |> list.map(field_name)
  |> string.join(",")
}

fn field_name(field: String) -> String {
  case string.split_once(field, ":") {
    Ok(#(name, _value)) -> name
    Error(Nil) -> field
  }
}
