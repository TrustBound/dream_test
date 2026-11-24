import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, Passed, TestResult, Unit}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/doc/reporters/json/format
import snippets/doc/reporters/json/format_pretty
import snippets/doc/reporters/json/render
import snippets_child_vm.{
  type ChildRun, ChildRun, it_runs_in_child_vm, progress_done_line,
}

/// The JSON of the example suite of `format` and `report`, with the values
/// that change from run to run made fixed by `without_run_values`.
const example_suite_json =
  "{\"version\":\"2.0\",\"timestamp_ms\":0,\"duration_ms\":0,\"system\":{\"os\":\"<os>\",\"otp_version\":\"<otp_version>\",\"gleam_stdlib_version\":\"<gleam_stdlib_version>\"},\"summary\":{\"total\":1,\"passed\":1,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":0,\"setup_stopped\":0},\"tests\":[{\"name\":\"passes\",\"full_name\":[\"Example Suite\",\"passes\"],\"only_path\":\"Example Suite/passes\",\"run_alone\":\"gleam test -- --only \\\"Example Suite/passes\\\"\",\"status\":\"passed\",\"duration_ms\":0,\"tags\":[],\"kind\":\"unit\",\"failures\":[]}],\"hook_failures\":[]}\n"

/// The pretty JSON of the example suite of `format_pretty` and
/// `report_pretty`, with the values that change from run to run made fixed
/// by `without_run_values`.
const example_suite_pretty_json =
  "{\n"
  <> "  \"version\": \"2.0\",\n"
  <> "  \"timestamp_ms\": 0,\n"
  <> "  \"duration_ms\": 0,\n"
  <> "  \"system\": {\n"
  <> "    \"os\": \"<os>\",\n"
  <> "    \"otp_version\": \"<otp_version>\",\n"
  <> "    \"gleam_stdlib_version\": \"<gleam_stdlib_version>\"\n"
  <> "  },\n"
  <> "  \"summary\": {\n"
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
  <> "        \"Example Suite\",\n"
  <> "        \"passes\"\n"
  <> "      ],\n"
  <> "      \"only_path\": \"Example Suite/passes\",\n"
  <> "      \"run_alone\": \"gleam test -- --only \\\"Example Suite/passes\\\"\",\n"
  <> "      \"status\": \"passed\",\n"
  <> "      \"duration_ms\": 0,\n"
  <> "      \"tags\": [],\n"
  <> "      \"kind\": \"unit\",\n"
  <> "      \"failures\": []\n"
  <> "    }\n"
  <> "  ],\n"
  <> "  \"hook_failures\": []\n"
  <> "}\n"

/// The pretty JSON of the cart suite of `pretty`, made fixed by
/// `without_run_values`.
const cart_suite_pretty_json =
  "{\n"
  <> "  \"version\": \"2.0\",\n"
  <> "  \"timestamp_ms\": 0,\n"
  <> "  \"duration_ms\": 0,\n"
  <> "  \"system\": {\n"
  <> "    \"os\": \"<os>\",\n"
  <> "    \"otp_version\": \"<otp_version>\",\n"
  <> "    \"gleam_stdlib_version\": \"<gleam_stdlib_version>\"\n"
  <> "  },\n"
  <> "  \"summary\": {\n"
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
  <> "      \"name\": \"starts empty\",\n"
  <> "      \"full_name\": [\n"
  <> "        \"Cart\",\n"
  <> "        \"starts empty\"\n"
  <> "      ],\n"
  <> "      \"only_path\": \"Cart/starts empty\",\n"
  <> "      \"run_alone\": \"gleam test -- --only \\\"Cart/starts empty\\\"\",\n"
  <> "      \"status\": \"passed\",\n"
  <> "      \"duration_ms\": 0,\n"
  <> "      \"tags\": [],\n"
  <> "      \"kind\": \"unit\",\n"
  <> "      \"failures\": []\n"
  <> "    }\n"
  <> "  ],\n"
  <> "  \"hook_failures\": []\n"
  <> "}\n"

/// The JSON of the two tests of the module example, made fixed by
/// `without_run_values`.
const module_example_json =
  "{\"version\":\"2.0\",\"timestamp_ms\":0,\"duration_ms\":0,\"system\":{\"os\":\"<os>\",\"otp_version\":\"<otp_version>\",\"gleam_stdlib_version\":\"<gleam_stdlib_version>\"},\"summary\":{\"total\":2,\"passed\":2,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":0,\"setup_stopped\":0},\"tests\":[{\"name\":\"outputs JSON format\",\"full_name\":[\"JSON Reporter\",\"outputs JSON format\"],\"only_path\":\"JSON Reporter/outputs JSON format\",\"run_alone\":\"gleam test -- --only \\\"JSON Reporter/outputs JSON format\\\"\",\"status\":\"passed\",\"duration_ms\":0,\"tags\":[],\"kind\":\"unit\",\"failures\":[]},{\"name\":\"includes test metadata\",\"full_name\":[\"JSON Reporter\",\"includes test metadata\"],\"only_path\":\"JSON Reporter/includes test metadata\",\"run_alone\":\"gleam test -- --only \\\"JSON Reporter/includes test metadata\\\"\",\"status\":\"passed\",\"duration_ms\":0,\"tags\":[],\"kind\":\"unit\",\"failures\":[]}],\"hook_failures\":[]}\n"

/// The JSON values that change from run to run, and the fixed text that
/// replaces each one, for compact and for pretty JSON:
/// - `timestamp_ms`, the time of the run, becomes 0.
/// - `duration_ms`, of the run and of each test, becomes 0.
/// - `os`, `otp_version` and `gleam_stdlib_version` of the machine become
///   `<os>`, `<otp_version>` and `<gleam_stdlib_version>`. The version of
///   gleam_stdlib is `unknown` when its application is not loaded, as in a
///   child VM.
const run_values = [
  #("\"timestamp_ms\":[0-9]+", "\"timestamp_ms\":0"),
  #("\"timestamp_ms\": [0-9]+", "\"timestamp_ms\": 0"),
  #("\"duration_ms\":[0-9]+", "\"duration_ms\":0"),
  #("\"duration_ms\": [0-9]+", "\"duration_ms\": 0"),
  #("\"os\":\"[^\"]*\"", "\"os\":\"<os>\""),
  #("\"os\": \"[^\"]*\"", "\"os\": \"<os>\""),
  #("\"otp_version\":\"[^\"]*\"", "\"otp_version\":\"<otp_version>\""),
  #("\"otp_version\": \"[^\"]*\"", "\"otp_version\": \"<otp_version>\""),
  #(
    "\"gleam_stdlib_version\":\"[^\"]*\"",
    "\"gleam_stdlib_version\":\"<gleam_stdlib_version>\"",
  ),
  #(
    "\"gleam_stdlib_version\": \"[^\"]*\"",
    "\"gleam_stdlib_version\": \"<gleam_stdlib_version>\"",
  ),
]

fn without_run_values(json: String) -> String {
  list.fold(run_values, json, fn(text, pattern_and_replacement) {
    let #(pattern, replacement) = pattern_and_replacement
    snippets_child_vm.replace(text, pattern, replacement)
  })
}

fn without_run_values_in(run: ChildRun) -> ChildRun {
  ChildRun(..run, output: without_run_values(run.output))
}

/// The JSON of the cart suite of `new` and `render`, made fixed by
/// `without_run_values`.
const cart_suite_json =
  "{\"version\":\"2.0\",\"timestamp_ms\":0,\"duration_ms\":0,\"system\":{\"os\":\"<os>\",\"otp_version\":\"<otp_version>\",\"gleam_stdlib_version\":\"<gleam_stdlib_version>\"},\"summary\":{\"total\":1,\"passed\":1,\"failed\":0,\"skipped\":0,\"pending\":0,\"timed_out\":0,\"setup_failed\":0,\"teardown_failed\":0,\"setup_stopped\":0},\"tests\":[{\"name\":\"starts empty\",\"full_name\":[\"Cart\",\"starts empty\"],\"only_path\":\"Cart/starts empty\",\"run_alone\":\"gleam test -- --only \\\"Cart/starts empty\\\"\",\"status\":\"passed\",\"duration_ms\":0,\"tags\":[],\"kind\":\"unit\",\"failures\":[]}],\"hook_failures\":[]}\n"

/// A run report of the one passed test of the cart suite.
fn cart_report() -> RunReport {
  types.run_report(
    tests: [
      TestResult(
        name: "starts empty",
        groups: ["Cart"],
        status: Passed,
        duration_ms: 3,
        tags: [],
        failures: [],
        kind: Unit,
      ),
    ],
    hook_failures: [],
    reporter_crashes: [],
  )
}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/json", [
    it_runs_in_child_vm("new main prints the JSON of the cart suite", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/json/new", "main")
        |> result.map(without_run_values_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(status: 0, output: cart_suite_json, error_output: "")),
      )
      |> or_fail_with("expected the JSON of the cart suite")
    }),
    it_runs_in_child_vm(
      "pretty main prints the pretty JSON of the cart suite",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/reporters/json/pretty", "main")
          |> result.map(without_run_values_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: cart_suite_pretty_json,
            error_output: "",
          )),
        )
        |> or_fail_with("expected the pretty JSON of the cart suite")
      },
    ),
    it("render_compact_json gives the JSON of the report", fn() {
      // Act
      let text = render.render_compact_json(cart_report())

      // Assert
      without_run_values(text)
      |> should
      |> be_equal(cart_suite_json)
      |> or_fail_with("expected the compact JSON of the cart report")
    }),
    it_runs_in_child_vm("the module example main prints the JSON report", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/json/module", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)
        |> result.map(without_run_values_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2) <> module_example_json,
          error_output: "",
        )),
      )
      |> or_fail_with("expected the progress line and the JSON of both tests")
    }),
    it("format main gives the JSON of the example suite", fn() {
      // Act
      let text = format.main()

      // Assert
      without_run_values(text)
      |> should
      |> be_equal(example_suite_json)
      |> or_fail_with("expected the JSON of the example suite")
    }),
    it("format_pretty main gives the pretty JSON of the example suite", fn() {
      // Act
      let text = format_pretty.main()

      // Assert
      without_run_values(text)
      |> should
      |> be_equal(example_suite_pretty_json)
      |> or_fail_with("expected the pretty JSON of the example suite")
    }),
    it_runs_in_child_vm(
      "report main prints the JSON of the example suite",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/reporters/json/report", "main")
          |> result.map(without_run_values_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(status: 0, output: example_suite_json, error_output: "")),
        )
        |> or_fail_with("expected the JSON of the example suite")
      },
    ),
    it_runs_in_child_vm(
      "report_pretty main prints the pretty JSON of the example suite",
      fn() {
        // Act
        let result =
          snippets_child_vm.run(
            "snippets/doc/reporters/json/report_pretty",
            "main",
          )
          |> result.map(without_run_values_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: example_suite_pretty_json,
            error_output: "",
          )),
        )
        |> or_fail_with("expected the pretty JSON of the example suite")
      },
    ),
  ])
}
