import dream_test/discover
import dream_test/file
import dream_test/gherkin/discover as gherkin_discover
import dream_test/gherkin/steps.{type StepContext, new, step}
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type AssertionResult, type TestResult, AssertionFailure, AssertionOk, Failed,
  Passed, SetupFailed, Unit,
}
import dream_test/unit.{describe, group, it, with_tags}
import dream_test/unit_context.{
  after_all, after_each, before_all, before_each, describe as ctx_describe,
  it as ctx_it,
}
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
            && info.full_name == ["root", "group", "leaf"]
            && info.tags == ["group", "leaf"]
            && info.kind == Unit
          {
            True -> Ok(ctx)
            False -> Error("metadata mismatch")
          }
        })
        |> runner.run()

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

      let assert [_r] = results

      file.read(log_path)
      |> should
      |> be_equal(Ok(
        "runner_before_suite\nsuite_before_all\nsuite_after_all\nrunner_after_suite\n",
      ))
      |> or_fail_with("runner suite hooks should wrap suite hooks")
    }),

    it(
      "before_all_suites failure skips tests and records after_all_suites failure",
      fn() {
        let suite_one =
          describe("suite_one", [
            it("a", fn() { panic as "should not run" }),
          ])

        let suite_two =
          describe("suite_two", [
            it("b", fn() { panic as "should not run" }),
          ])

        let results =
          runner.new([suite_one, suite_two])
          |> runner.before_all_suites(fn(_suites) { Error("nope") })
          |> runner.after_all_suites(fn(_suites) { Error("cleanup") })
          |> runner.run()

        let assert [r1, r2, r3] = results

        let _ =
          #(r1.status, first_failure_operator(r1))
          |> should
          |> be_equal(#(Failed, Some("before_all_suites")))
          |> or_fail_with("first test should fail due to before_all_suites")

        let _ =
          #(r2.status, first_failure_operator(r2))
          |> should
          |> be_equal(#(Failed, Some("before_all_suites")))
          |> or_fail_with("second test should fail due to before_all_suites")

        let _ =
          #(r3.name, first_failure_operator(r3))
          |> should
          |> be_equal(#("<after_all_suites>", Some("after_all_suites")))
          |> or_fail_with("after_all_suites failure should be reported")
      },
    ),

    it(
      "before_each_suite failure skips suite tests and runs after_each_suite",
      fn() {
        let suite_one =
          describe("suite_one", [
            it("boom", fn() { panic as "should not run" }),
          ])

        let suite_two =
          describe("suite_two", [
            it("ok", fn() { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite_one, suite_two])
          |> runner.before_each_suite(fn(suite) {
            case suite.name == "suite_one" {
              True -> Error("boom")
              False -> Ok(Nil)
            }
          })
          |> runner.after_each_suite(fn(suite) {
            case suite.name == "suite_one" {
              True -> Error("cleanup")
              False -> Ok(Nil)
            }
          })
          |> runner.run()

        let assert [r1, r2, r3] = results

        let _ =
          #(r1.status, first_failure_operator(r1))
          |> should
          |> be_equal(#(Failed, Some("before_each_suite")))
          |> or_fail_with("suite_one test should fail due to before_each_suite")

        let _ =
          #(r2.name, first_failure_operator(r2))
          |> should
          |> be_equal(#("<after_each_suite>", Some("after_each_suite")))
          |> or_fail_with("after_each_suite failure should be reported")

        let _ =
          r3.status
          |> should
          |> be_equal(Passed)
          |> or_fail_with("suite_two test should pass")
      },
    ),

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

    it("after_each_test failure marks test Failed", fn() {
      let suite =
        describe("after_suite", [
          it("after", fn() { Ok(AssertionOk) }),
        ])

      let results =
        runner.new([suite])
        |> runner.after_each_test(fn(info, _ctx: Nil) {
          case info.name == "after" {
            True -> Error("boom")
            False -> Ok(Nil)
          }
        })
        |> runner.run()

      let assert [r1] = results
      let _ =
        #(r1.status, first_failure_operator(r1))
        |> should
        |> be_equal(#(Failed, Some("after_each_test")))
        |> or_fail_with("after_each_test failure should mark test Failed")
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
        new()
        |> step("ok", step_ok)

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

fn first_failure_operator(result: TestResult) -> Option(String) {
  case result.failures {
    [] -> None
    [AssertionFailure(operator: operator, message: _message, payload: _), ..] ->
      Some(operator)
  }
}

fn step_ok(_context: StepContext) -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}
