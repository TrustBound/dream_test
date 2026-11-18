import dream_test/discover
import dream_test/file
import dream_test/gherkin/discover as gherkin_discover
import dream_test/gherkin/steps.{type StepContext, new}
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type TestResult, AfterAllSuitesHook, AfterEachSuiteHook, AfterEachTestHook,
  AssertionOk, Passed, SetupFailed, TeardownFailure, Unit,
}
import dream_test/unit.{describe, group, it, with_tags}
import dream_test/unit_context.{
  after_all, after_each, before_all, before_each, describe as ctx_describe,
  it as ctx_it,
}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn tests() {
  describe("runner hooks", [
    it("runner per-test hooks wrap suite hooks", fn() {
      let log_path = "test/fixtures/file/temp/runner_hooks_order.txt"

      let suite =
        ctx_describe("root", Nil, [
          before_all(fn(_ctx: Nil) { write_string(log_path, "") }),
          before_each(fn(_ctx: Nil) { append_line(log_path, "suite_before\n") }),
          after_each(fn(_ctx: Nil) { append_line(log_path, "suite_after\n") }),
          ctx_it("passes", fn(_ctx: Nil) { Ok(AssertionOk) }),
        ])

      let results =
        runner.new([suite])
        |> runner.max_concurrency(1)
        |> runner.before_each_test(fn(_info, ctx: Nil) {
          log_and_keep_context(log_path, "runner_before\n", ctx)
        })
        |> runner.after_each_test(fn(_info, _ctx: Nil) {
          append_line(log_path, "runner_after\n")
        })
        |> runner.run()
        |> types.report_tests

      let assert [_r] = results

      file.read(log_path)
      |> should
      |> be_equal(Ok("runner_before\nsuite_before\nsuite_after\nrunner_after\n"))
      |> or_fail_with("runner hooks should wrap suite hooks")
    }),

    it("runner before_each_test sees full_name, tags, and kind", fn() {
      let suite =
        describe("root", [
          group("group", [
            it("leaf", fn() { Ok(AssertionOk) })
            |> with_tags(["leaf"]),
          ])
          |> with_tags(["group"]),
        ])

      let results =
        runner.new([suite])
        |> runner.before_each_test(fn(info, ctx: Nil) {
          case
            info.name == "leaf"
            && types.full_name(info.groups, info.name)
            == ["root", "group", "leaf"]
            && info.tags == ["group", "leaf"]
            && info.kind == Unit
          {
            True -> Ok(ctx)
            False -> Error("metadata mismatch")
          }
        })
        |> runner.run()
        |> types.report_tests

      let assert [r1] = results

      let _ =
        r1.status
        |> should
        |> be_equal(Passed)
        |> or_fail_with("expected metadata to be correct")
    }),

    it("runner per-suite hooks wrap suite before_all/after_all", fn() {
      let log_path = "test/fixtures/file/temp/runner_hooks_suite_order.txt"
      let _ = write_string(log_path, "")

      let suite =
        ctx_describe("suite_one", Nil, [
          before_all(fn(_ctx: Nil) {
            append_line(log_path, "suite_before_all\n")
          }),
          after_all(fn(_ctx: Nil) { append_line(log_path, "suite_after_all\n") }),
          ctx_it("passes", fn(_ctx: Nil) { Ok(AssertionOk) }),
        ])

      let results =
        runner.new([suite])
        |> runner.max_concurrency(1)
        |> runner.before_each_suite(fn(_suite) {
          append_line(log_path, "runner_before_suite\n")
        })
        |> runner.after_each_suite(fn(_suite) {
          append_line(log_path, "runner_after_suite\n")
        })
        |> runner.run()
        |> types.report_tests

      let assert [_r] = results

      file.read(log_path)
      |> should
      |> be_equal(Ok(
        "runner_before_suite\nsuite_before_all\nsuite_after_all\nrunner_after_suite\n",
      ))
      |> or_fail_with("runner suite hooks should wrap suite hooks")
    }),

    it("a before_all_suites failure gives SetupFailed to every test", fn() {
      runner.new([
        describe("suite_one", [it("a", fn() { panic as "should not run" })]),
        describe("suite_two", [it("b", fn() { panic as "should not run" })]),
      ])
      |> runner.before_all_suites(fn(_suites) { Error("nope") })
      |> runner.run()
      |> types.report_tests
      |> status_and_operators
      |> should
      |> be_equal([
        #("a", SetupFailed, ["before_all_suites"]),
        #("b", SetupFailed, ["before_all_suites"]),
      ])
      |> or_fail_with("every test should be SetupFailed")
    }),

    it("after_all_suites runs after a before_all_suites failure", fn() {
      runner.new([describe("suite", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.before_all_suites(fn(_suites) { Error("nope") })
      |> runner.after_all_suites(fn(_suites) { Error("cleanup") })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(hook: AfterAllSuitesHook, scope: [], message: "cleanup"),
      ])
      |> or_fail_with("after_all_suites should run and its failure be kept")
    }),

    it("an after_all_suites failure adds no test result", fn() {
      runner.new([describe("suite", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.after_all_suites(fn(_suites) { Error("cleanup") })
      |> runner.run()
      |> types.report_tests
      |> status_and_operators
      |> should
      |> be_equal([#("a", Passed, [])])
      |> or_fail_with("a failing after_all_suites should add no test result")
    }),

    it("an after_all_suites failure does not stop the next one", fn() {
      runner.new([describe("suite", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.after_all_suites(fn(_suites) { Error("first") })
      |> runner.after_all_suites(fn(_suites) { Error("second") })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(hook: AfterAllSuitesHook, scope: [], message: "first"),
        TeardownFailure(hook: AfterAllSuitesHook, scope: [], message: "second"),
      ])
      |> or_fail_with("every after_all_suites hook should run")
    }),

    it("a before_each_suite failure gives SetupFailed to its suite only", fn() {
      runner.new([
        describe("suite_one", [it("boom", fn() { panic as "should not run" })]),
        describe("suite_two", [it("ok", fn() { Ok(AssertionOk) })]),
      ])
      |> runner.before_each_suite(fail_for_suite_one)
      |> runner.run()
      |> types.report_tests
      |> status_and_operators
      |> should
      |> be_equal([
        #("boom", SetupFailed, ["before_each_suite"]),
        #("ok", Passed, []),
      ])
      |> or_fail_with("only the tests of suite_one should be SetupFailed")
    }),

    it("after_each_suite runs after a before_each_suite failure", fn() {
      runner.new([
        describe("suite_one", [it("boom", fn() { panic as "should not run" })]),
      ])
      |> runner.before_each_suite(fail_for_suite_one)
      |> runner.after_each_suite(fail_for_suite_one)
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachSuiteHook,
          scope: ["suite_one"],
          message: "suite_one failed",
        ),
      ])
      |> or_fail_with("after_each_suite should run and its failure be kept")
    }),

    it("an after_each_suite failure does not stop the next one", fn() {
      runner.new([describe("suite", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.after_each_suite(fn(_suite) { Error("first") })
      |> runner.after_each_suite(fn(_suite) { Error("second") })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachSuiteHook,
          scope: ["suite"],
          message: "first",
        ),
        TeardownFailure(
          hook: AfterEachSuiteHook,
          scope: ["suite"],
          message: "second",
        ),
      ])
      |> or_fail_with("every after_each_suite hook should run")
    }),

    it(
      "before_each_test failure yields SetupFailed under parallel execution",
      fn() {
        let suite =
          describe("parallel_suite", [
            it("ok", fn() { Ok(AssertionOk) }),
            it("fail", fn() { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite])
          |> runner.max_concurrency(2)
          |> runner.before_each_test(fn(info, ctx: Nil) {
            case info.name == "fail" {
              True -> Error("nope")
              False -> Ok(ctx)
            }
          })
          |> runner.run()
          |> types.report_tests

        case find_result_by_name(results, "fail") {
          Some(result) ->
            result.status
            |> should
            |> be_equal(SetupFailed)
            |> or_fail_with("failed test should be SetupFailed")
          None -> Ok(fail_with("expected test named 'fail'"))
        }
      },
    ),

    it("an after_each_test failure keeps the status of the test", fn() {
      runner.new([describe("suite", [it("after", fn() { Ok(AssertionOk) })])])
      |> runner.after_each_test(fn(_info, _ctx: Nil) { Error("boom") })
      |> runner.run()
      |> types.report_tests
      |> status_and_operators
      |> should
      |> be_equal([#("after", Passed, [])])
      |> or_fail_with("a failing after_each_test should not change the status")
    }),

    it("after_each_test runs after a failing after_each_test", fn() {
      runner.new([describe("suite", [it("after", fn() { Ok(AssertionOk) })])])
      |> runner.after_each_test(fn(_info, _ctx: Nil) { Error("first") })
      |> runner.after_each_test(fn(_info, _ctx: Nil) { Error("second") })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachTestHook,
          scope: ["suite", "after"],
          message: "first",
        ),
        TeardownFailure(
          hook: AfterEachTestHook,
          scope: ["suite", "after"],
          message: "second",
        ),
      ])
      |> or_fail_with("every after_each_test hook should run")
    }),

    it("unit discovery populates source with module name", fn() {
      let discovery = discover.tests("dream_test/runner_api_test.gleam")

      case discover.list_modules(discovery) {
        Ok([module_name]) -> {
          let log_path =
            "test/fixtures/file/temp/runner_hooks_source_module.txt"
          let _ = write_string(log_path, "")
          let suites = discover.to_suites(discovery)

          let _ =
            runner.new(suites)
            |> runner.before_each_suite(fn(suite) {
              case suite.source {
                Some(value) -> write_string(log_path, value)
                None -> write_string(log_path, "<none>")
              }
            })
            |> runner.run()
            |> types.report_tests

          file.read(log_path)
          |> should
          |> be_equal(Ok(module_name))
          |> or_fail_with("suite source should match module name")
        }
        _ -> Ok(fail_with("expected one discovered module"))
      }
    }),

    it("gherkin discovery populates source with .feature path", fn() {
      let feature_path = "test/fixtures/file/temp/runner_hooks_source.feature"
      let content =
        "Feature: Source\n" <> "\n" <> "Scenario: One\n" <> "  Given ok\n"

      let _ = file.write(feature_path, content)

      let registry =
        new(initial: Nil)
        |> steps.given("ok", step_ok)

      let suite =
        gherkin_discover.features(feature_path)
        |> gherkin_discover.with_registry(registry)
        |> gherkin_discover.to_suite("gherkin_source")

      let log_path = "test/fixtures/file/temp/runner_hooks_source_gherkin.txt"
      let _ = write_string(log_path, "")

      let _ =
        runner.new([suite])
        |> runner.before_each_test(fn(info, ctx: Nil) {
          case info.source {
            Some(value) ->
              case write_string(log_path, value) {
                Ok(_) -> Ok(ctx)
                Error(e) -> Error(e)
              }
            None -> Error("missing source")
          }
        })
        |> runner.run()
        |> types.report_tests

      file.read(log_path)
      |> should
      |> be_equal(Ok(feature_path))
      |> or_fail_with("gherkin test source should be .feature path")
    }),
  ])
}

fn append_line(path: String, line: String) -> Result(Nil, String) {
  case file.read(path) {
    Ok(existing) -> write_string(path, existing <> line)
    Error(e) -> Error(file.error_to_string(e))
  }
}

fn write_string(path: String, content: String) -> Result(Nil, String) {
  case file.write(path, content) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(file.error_to_string(e))
  }
}

fn log_and_keep_context(
  path: String,
  line: String,
  ctx: Nil,
) -> Result(Nil, String) {
  case append_line(path, line) {
    Ok(_) -> Ok(ctx)
    Error(e) -> Error(e)
  }
}

fn find_result_by_name(
  results: List(TestResult),
  name: String,
) -> Option(TestResult) {
  case results {
    [] -> None
    [r, ..rest] ->
      case r.name == name {
        True -> Some(r)
        False -> find_result_by_name(rest, name)
      }
  }
}

fn step_ok(_state: Nil, _context: StepContext) -> Result(Nil, String) {
  Ok(Nil)
}

fn fail_for_suite_one(suite: types.SuiteInfo) -> Result(Nil, String) {
  case suite.name == "suite_one" {
    True -> Error("suite_one failed")
    False -> Ok(Nil)
  }
}

fn status_and_operators(
  results: List(TestResult),
) -> List(#(String, types.Status, List(String))) {
  list.map(results, fn(result) {
    #(
      result.name,
      result.status,
      list.map(result.failures, fn(failure) { failure.operator }),
    )
  })
}
