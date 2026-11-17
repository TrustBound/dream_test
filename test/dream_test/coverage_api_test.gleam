//// Black-box tests of `dream_test/coverage`.
////
//// Tests that start `cover` run in a new peer node, because `cover` runs
//// once per BEAM instance and this test run may already be measuring itself.

import coverage_fixtures/nested/deep
import coverage_fixtures/sample
import dream_test/coverage.{
  type CoverageError, type CoverageSession, type StartCause, BelowMinimumPercent,
  CoberturaWriteFailed, CoverAlreadyRunning, CoverStartFailed, HtmlDeleteFailed,
  HtmlSourceReadFailed, HtmlWriteFailed, InvalidMinimumPercent, JsonWriteFailed,
  LcovWriteFailed, MarkdownWriteFailed, NoSourceFiles, SourceDirectoryNotFound,
  SourceDirectoryOutsideSourceRoot,
}
import dream_test/coverage/report.{
  type CoverageReport, type LineCoverage, LineCoverage,
}
import dream_test/coverage_child_support.{
  add_source, child_project, compile_source, make_unreadable, run_in_child,
}
import dream_test/file.{
  FileSystemError, IsDirectory, NotFound, PermissionDenied, read, write,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, group, it}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

@external(erlang, "dream_test_coverage_test_ffi", "run_in_peer")
fn run_in_peer(function: fn() -> a) -> Result(a, String)

fn fixture_config() {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
}

/// The start error, or a message when start unexpectedly succeeded.
fn start_error(
  result: Result(CoverageSession, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected start to fail")
  }
}

/// Every file of a report as `#(source_path, lines)`.
fn file_lines(
  coverage_report: CoverageReport,
) -> List(#(String, List(LineCoverage))) {
  list.map(report.files(coverage_report), fn(file) {
    #(report.source_path(file), report.lines(file))
  })
}

/// Lines 1..total, where the first `hit` lines ran once.
fn report_with_counts(hit: Int, total: Int) -> CoverageReport {
  report.new([
    report.file("src/app/cart.gleam", counted_lines(1, total, hit, [])),
  ])
}

fn counted_lines(
  line: Int,
  total: Int,
  hit: Int,
  accumulated: List(LineCoverage),
) -> List(LineCoverage) {
  case line > total {
    True -> list.reverse(accumulated)
    False -> {
      let calls = case line <= hit {
        True -> 1
        False -> 0
      }
      counted_lines(line + 1, total, hit, [
        LineCoverage(line: line, calls: calls),
        ..accumulated
      ])
    }
  }
}

/// Start coverage, run `classify(1)`, and finish, all in a new peer node.
/// The Cobertura timestamp is the time of the run, so replace its value
/// with `T` before comparing.
fn without_timestamp(xml: String) -> String {
  case string.split_once(xml, " timestamp=\"") {
    Ok(#(before, after)) ->
      case string.split_once(after, "\"") {
        Ok(#(_, rest)) -> before <> " timestamp=\"T\"" <> rest
        Error(Nil) -> xml
      }
    Error(Nil) -> xml
  }
}

fn fixture_json() {
  string.concat([
    "{\"version\":1,\"files\":[",
    "{\"path\":\"test/coverage_fixtures/coverage_fixture_ffi.erl\",\"lines_hit\":0,\"lines_total\":1,\"percent\":0.0,\"missing\":[{\"first\":6,\"last\":6}],\"ignored\":[]},",
    "{\"path\":\"test/coverage_fixtures/nested/deep.gleam\",\"lines_hit\":0,\"lines_total\":1,\"percent\":0.0,\"missing\":[{\"first\":4,\"last\":4}],\"ignored\":[]},",
    "{\"path\":\"test/coverage_fixtures/sample.gleam\",\"lines_hit\":2,\"lines_total\":4,\"percent\":50.0,\"missing\":[{\"first\":9,\"last\":9},{\"first\":14,\"last\":14}],\"ignored\":[]}],",
    "\"excluded_files\":[],",
    "\"total\":{\"lines_hit\":2,\"lines_total\":6,\"percent\":33.3},",
    "\"minimum_percent\":10.0,\"minimum_percent_per_file\":5.0}\n",
  ])
}

fn fixture_cobertura() {
  string.concat([
    "<?xml version=\"1.0\" ?>\n",
    "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">\n",
    "<coverage line-rate=\"0.3333\" branch-rate=\"0\" lines-covered=\"2\" lines-valid=\"6\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"T\">\n",
    "  <sources>\n",
    "    <source>.</source>\n",
    "  </sources>\n",
    "  <packages>\n",
    "    <package name=\"test.coverage_fixtures\" line-rate=\"0.4000\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    "        <class name=\"coverage_fixture_ffi.erl\" filename=\"test/coverage_fixtures/coverage_fixture_ffi.erl\" line-rate=\"0.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"6\" hits=\"0\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "        <class name=\"sample.gleam\" filename=\"test/coverage_fixtures/sample.gleam\" line-rate=\"0.5000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"7\" hits=\"1\"/>\n",
    "            <line number=\"8\" hits=\"1\"/>\n",
    "            <line number=\"9\" hits=\"0\"/>\n",
    "            <line number=\"14\" hits=\"0\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "      </classes>\n",
    "    </package>\n",
    "    <package name=\"test.coverage_fixtures.nested\" line-rate=\"0.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    "        <class name=\"deep.gleam\" filename=\"test/coverage_fixtures/nested/deep.gleam\" line-rate=\"0.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"4\" hits=\"0\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "      </classes>\n",
    "    </package>\n",
    "  </packages>\n",
    "</coverage>\n",
  ])
}

fn fixture_markdown() {
  string.concat([
    "## Coverage\n\n",
    "| File | Lines | Cover | Missing | Excluded |\n",
    "| --- | ---: | ---: | --- | --- |\n",
    "| test/coverage\\_fixtures/coverage\\_fixture\\_ffi.erl | 0/1 | 0.0% | 6 |  |\n",
    "| test/coverage\\_fixtures/nested/deep.gleam | 0/1 | 0.0% | 4 |  |\n",
    "| test/coverage\\_fixtures/sample.gleam | 2/4 | 50.0% | 9, 14 |  |\n",
    "| Total | 2/6 | 33.3% |  |  |\n",
  ])
}

/// The text after `<body>` of an HTML page.
fn html_body(page: String) -> String {
  case string.split_once(page, "<body>\n") {
    Ok(#(_, rest)) -> rest
    Error(Nil) -> page
  }
}

fn fixture_deep_page_body() {
  string.concat([
    "<p><a href=\"../../../../index.html\">All files</a></p>\n",
    "<h1>test/coverage_fixtures/nested/deep.gleam</h1>\n",
    "<p>Lines: 0/1. Cover: <span class=\"low\">0.0%</span>.</p>\n",
    "<table class=\"source\">\n",
    "<thead><tr><th class=\"number\">Line</th><th class=\"number\">Hits</th><th>Source</th></tr></thead>\n",
    "<tbody>\n",
    "<tr class=\"not-executable\"><td class=\"number\">1</td><td class=\"number\"></td><td>//// Fixture for the coverage tests: a nested module (`nested@deep`).</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">2</td><td class=\"number\"></td><td></td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">3</td><td class=\"number\"></td><td>pub fn answer() -&gt; Int {</td></tr>\n",
    "<tr class=\"missed\"><td class=\"number\">4</td><td class=\"number\">0</td><td>  42</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">5</td><td class=\"number\"></td><td>}</td></tr>\n",
    "</tbody>\n",
    "</table>\n",
    "</body>\n",
    "</html>\n",
  ])
}

fn is_ok(value: Result(a, b)) -> Bool {
  result.is_ok(value)
}

/// Set the permission bits of a file or folder, for tests that need a
/// folder that cannot be changed.
@external(erlang, "file", "change_mode")
fn change_mode(path: String, mode: Int) -> Dynamic

fn output_path(name: String) -> String {
  "test/tmp/coverage_api_test/" <> int.to_string(unique_port()) <> "_" <> name
}

fn measure_classify(
  config: coverage.CoverageConfig,
) -> Result(Result(CoverageReport, CoverageError), String) {
  run_in_peer(fn() {
    case coverage.start(config) {
      Ok(session) -> {
        let _ = sample.classify(1)
        coverage.finish(session)
      }
      Error(error) -> Error(error)
    }
  })
}

fn start_cause(error: CoverageError) -> Result(StartCause, String) {
  case error {
    CoverStartFailed(cause, _raw) -> Ok(cause)
    _ -> Error("expected CoverStartFailed")
  }
}

pub fn tests() {
  describe("dream_test/coverage", [
    group("settings", [
      it("new does not show missing lines", fn() {
        coverage.new()
        |> coverage.shows_missing()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected missing lines to be hidden by default")
      }),
      it("new does not show excluded lines and files", fn() {
        coverage.new()
        |> coverage.shows_excluded()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected exclusions to be listed only on request")
      }),
      it("show_excluded turns the Excluded column on", fn() {
        coverage.new()
        |> coverage.show_excluded()
        |> coverage.shows_excluded()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected exclusions to be listed")
      }),
      it("show_missing turns the Missing column on", fn() {
        coverage.new()
        |> coverage.show_missing()
        |> coverage.shows_missing()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected missing lines to be shown")
      }),
      it("new prints the table without colour", fn() {
        coverage.new()
        |> coverage.uses_color()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected no colour by default")
      }),
      it("color turns colour on", fn() {
        coverage.new()
        |> coverage.color()
        |> coverage.uses_color()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected colour")
      }),
      it("new does not sort by coverage", fn() {
        coverage.new()
        |> coverage.sorts_by_coverage()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected the report order by default")
      }),
      it("sort_by_coverage turns the coverage order on", fn() {
        coverage.new()
        |> coverage.sort_by_coverage()
        |> coverage.sorts_by_coverage()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected the coverage order")
      }),
      it("new does not hide complete files", fn() {
        coverage.new()
        |> coverage.hides_complete()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected every file to be shown by default")
      }),
      it("hide_complete turns hiding complete files on", fn() {
        coverage.new()
        |> coverage.hide_complete()
        |> coverage.hides_complete()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected complete files to be hidden")
      }),
      it("new sets no minimum", fn() {
        coverage.new()
        |> coverage.minimum()
        |> should
        |> be_equal(None)
        |> or_fail_with("expected no minimum")
      }),
      it("minimum returns the value given to minimum_percent", fn() {
        coverage.new()
        |> coverage.minimum_percent(80.0)
        |> coverage.minimum()
        |> should
        |> be_equal(Some(80.0))
        |> or_fail_with("expected 80.0")
      }),
      it("new writes LCOV to build/coverage/lcov.info", fn() {
        coverage.new()
        |> coverage.lcov_file()
        |> should
        |> be_equal(Some("build/coverage/lcov.info"))
        |> or_fail_with("expected the default LCOV path")
      }),
      it("lcov_path changes the LCOV file", fn() {
        coverage.new()
        |> coverage.lcov_path("build/coverage/unit.lcov")
        |> coverage.lcov_file()
        |> should
        |> be_equal(Some("build/coverage/unit.lcov"))
        |> or_fail_with("expected the new LCOV path")
      }),
      it("no_lcov turns the LCOV file off", fn() {
        coverage.new()
        |> coverage.no_lcov()
        |> coverage.lcov_file()
        |> should
        |> be_equal(None)
        |> or_fail_with("expected no LCOV file")
      }),
    ]),

    group("start errors", [
      it("returns SourceDirectoryNotFound for a missing directory", fn() {
        coverage.new()
        |> coverage.source_directory("src/no_such_directory")
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(SourceDirectoryNotFound("src/no_such_directory")))
        |> or_fail_with("expected SourceDirectoryNotFound")
      }),
      it(
        "returns SourceDirectoryOutsideSourceRoot outside src, test and dev",
        fn() {
          coverage.new()
          |> coverage.source_directory("examples/snippets/src")
          |> coverage.start()
          |> start_error()
          |> should
          |> be_equal(
            Ok(SourceDirectoryOutsideSourceRoot("examples/snippets/src")),
          )
          |> or_fail_with("expected SourceDirectoryOutsideSourceRoot")
        },
      ),
      it("returns NoSourceFiles for a directory without source files", fn() {
        let directory =
          "test/tmp/coverage_api_test/empty_" <> int.to_string(unique_port())
        let _ = write(directory <> "/notes.txt", "not source")
        coverage.new()
        |> coverage.source_directory(directory)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(NoSourceFiles(directory)))
        |> or_fail_with("expected NoSourceFiles")
      }),
      it("returns InvalidMinimumPercent for a negative minimum", fn() {
        coverage.new()
        |> coverage.minimum_percent(-1.0)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercent(-1.0)))
        |> or_fail_with("expected InvalidMinimumPercent for -1.0")
      }),
      it("returns InvalidMinimumPercent for a minimum above 100", fn() {
        coverage.new()
        |> coverage.minimum_percent(100.5)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercent(100.5)))
        |> or_fail_with("expected InvalidMinimumPercent for 100.5")
      }),
      it("returns CoverAlreadyRunning for a second start", fn() {
        run_in_peer(fn() {
          let _ = coverage.start(fixture_config())
          case coverage.start(fixture_config()) {
            Error(error) -> start_cause(error)
            Ok(_) -> Error("expected the second start to fail")
          }
        })
        |> should
        |> be_equal(Ok(Ok(CoverAlreadyRunning)))
        |> or_fail_with("expected CoverAlreadyRunning")
      }),
    ]),

    group("start and finish", [
      it("report every source file with each executable line", fn() {
        case measure_classify(fixture_config()) {
          Ok(Ok(coverage_report)) -> Ok(file_lines(coverage_report))
          other -> Error(other)
        }
        |> should
        |> be_equal(
          Ok([
            #("test/coverage_fixtures/coverage_fixture_ffi.erl", [
              LineCoverage(line: 6, calls: 0),
            ]),
            #("test/coverage_fixtures/nested/deep.gleam", [
              LineCoverage(line: 4, calls: 0),
            ]),
            #("test/coverage_fixtures/sample.gleam", [
              LineCoverage(line: 7, calls: 1),
              LineCoverage(line: 8, calls: 1),
              LineCoverage(line: 9, calls: 0),
              LineCoverage(line: 14, calls: 0),
            ]),
          ]),
        )
        |> or_fail_with("expected the fixture lines")
      }),
      it("measure a folder inside a source root with its module names", fn() {
        run_in_peer(fn() {
          let config =
            fixture_config()
            |> coverage.source_directory("./test/coverage_fixtures/nested/")
          case coverage.start(config) {
            Ok(session) -> {
              let _ = deep.answer()
              coverage.finish(session)
            }
            Error(error) -> Error(error)
          }
        })
        |> should
        |> be_equal(
          Ok(
            Ok(
              report.new([
                report.file("test/coverage_fixtures/nested/deep.gleam", [
                  LineCoverage(line: 4, calls: 1),
                ]),
              ]),
            ),
          ),
        )
        |> or_fail_with("expected nested@deep to be measured")
      }),
      it("write the LCOV file", fn() {
        let path =
          "test/tmp/coverage_api_test/lcov_"
          <> int.to_string(unique_port())
          <> ".info"
        let _ = measure_classify(fixture_config() |> coverage.lcov_path(path))
        read(path)
        |> should
        |> be_equal(Ok(
          "TN:\nSF:test/coverage_fixtures/coverage_fixture_ffi.erl\nDA:6,0\nLF:1\nLH:0\nend_of_record\n"
          <> "TN:\nSF:test/coverage_fixtures/nested/deep.gleam\nDA:4,0\nLF:1\nLH:0\nend_of_record\n"
          <> "TN:\nSF:test/coverage_fixtures/sample.gleam\nDA:7,1\nDA:8,1\nDA:9,0\nDA:14,0\nLF:4\nLH:2\nend_of_record\n",
        ))
        |> or_fail_with("expected the LCOV records")
      }),
      it("return LcovWriteFailed when the LCOV path is a directory", fn() {
        measure_classify(fixture_config() |> coverage.lcov_path("test"))
        |> should
        |> be_equal(Ok(Error(LcovWriteFailed("test", IsDirectory("test")))))
        |> or_fail_with("expected LcovWriteFailed")
      }),
      it("write the JSON, Cobertura and Markdown files", fn() {
        let json_path = output_path("coverage.json")
        let cobertura_path = output_path("cobertura.xml")
        let markdown_path = output_path("coverage.md")
        let _ =
          measure_classify(
            fixture_config()
            |> coverage.minimum_percent(10.0)
            |> coverage.minimum_percent_per_file(5.0)
            |> coverage.json_path(json_path)
            |> coverage.cobertura_path(cobertura_path)
            |> coverage.markdown_path(markdown_path),
          )
        #(
          read(json_path),
          result.map(read(cobertura_path), without_timestamp),
          read(markdown_path),
        )
        |> should
        |> be_equal(#(
          Ok(fixture_json()),
          Ok(fixture_cobertura()),
          Ok(fixture_markdown()),
        ))
        |> or_fail_with("expected the three files")
      }),
      it("return JsonWriteFailed when the JSON path is a directory", fn() {
        measure_classify(fixture_config() |> coverage.json_path("test"))
        |> should
        |> be_equal(Ok(Error(JsonWriteFailed("test", IsDirectory("test")))))
        |> or_fail_with("expected JsonWriteFailed")
      }),
      it(
        "return CoberturaWriteFailed when the Cobertura path is a directory",
        fn() {
          measure_classify(fixture_config() |> coverage.cobertura_path("test"))
          |> should
          |> be_equal(
            Ok(Error(CoberturaWriteFailed("test", IsDirectory("test")))),
          )
          |> or_fail_with("expected CoberturaWriteFailed")
        },
      ),
      it(
        "return MarkdownWriteFailed when the Markdown path is a directory",
        fn() {
          measure_classify(fixture_config() |> coverage.markdown_path("test"))
          |> should
          |> be_equal(
            Ok(Error(MarkdownWriteFailed("test", IsDirectory("test")))),
          )
          |> or_fail_with("expected MarkdownWriteFailed")
        },
      ),
      it("write the HTML index and a page per file", fn() {
        let directory = output_path("html")
        let _ =
          measure_classify(fixture_config() |> coverage.html_path(directory))
        #(
          is_ok(read(directory <> "/index.html")),
          is_ok(read(
            directory <> "/files/test/coverage_fixtures/sample.gleam.html",
          )),
          is_ok(read(
            directory
            <> "/files/test/coverage_fixtures/coverage_fixture_ffi.erl.html",
          )),
          result.map(
            read(
              directory
              <> "/files/test/coverage_fixtures/nested/deep.gleam.html",
            ),
            html_body,
          ),
        )
        |> should
        |> be_equal(#(True, True, True, Ok(fixture_deep_page_body())))
        |> or_fail_with("expected the index and three pages")
      }),
      it("return HtmlWriteFailed when a page path is a directory", fn() {
        let directory = output_path("html_blocked")
        let index_path = directory <> "/index.html"
        let _ = write(index_path <> "/blocker", "")
        measure_classify(fixture_config() |> coverage.html_path(directory))
        |> should
        |> be_equal(
          Ok(Error(HtmlWriteFailed(index_path, IsDirectory(index_path)))),
        )
        |> or_fail_with("expected HtmlWriteFailed")
      }),
      it("return HtmlWriteFailed when a source page cannot be written", fn() {
        let directory = output_path("html_page_blocked")
        let page_path =
          directory
          <> "/files/test/coverage_fixtures/coverage_fixture_ffi.erl.html"
        let _ = write(directory <> "/keep.txt", "")
        let _ = change_mode(directory, 0o555)
        let result =
          measure_classify(fixture_config() |> coverage.html_path(directory))
        let _ = change_mode(directory, 0o755)
        result
        |> should
        |> be_equal(Ok(Error(HtmlWriteFailed(page_path, NotFound(page_path)))))
        |> or_fail_with("expected HtmlWriteFailed for the page")
      }),
      it("delete a page from an earlier run", fn() {
        let directory = output_path("html_stale")
        let stale_page = directory <> "/files/src/removed.gleam.html"
        let _ = write(stale_page, "stale")
        let _ =
          measure_classify(fixture_config() |> coverage.html_path(directory))
        read(stale_page)
        |> should
        |> be_equal(Error(NotFound(stale_page)))
        |> or_fail_with("expected the stale page to be deleted")
      }),
      it("keep other files in the HTML directory", fn() {
        let directory = output_path("html_own_file")
        let own_file = directory <> "/notes.txt"
        let _ = write(directory <> "/files/src/removed.gleam.html", "stale")
        let _ = write(own_file, "mine")
        let _ =
          measure_classify(fixture_config() |> coverage.html_path(directory))
        read(own_file)
        |> should
        |> be_equal(Ok("mine"))
        |> or_fail_with("expected the user's own file to stay")
      }),
      it("return HtmlDeleteFailed when old pages cannot be deleted", fn() {
        let directory = output_path("html_delete_blocked")
        let files_path = directory <> "/files"
        let locked = files_path <> "/locked"
        let _ = write(locked <> "/page.html", "stale")
        let _ = change_mode(locked, 0o555)
        let result =
          measure_classify(fixture_config() |> coverage.html_path(directory))
        let _ = change_mode(locked, 0o755)
        result
        |> should
        |> be_equal(
          Ok(
            Error(HtmlDeleteFailed(
              files_path,
              FileSystemError(files_path, "eexist"),
            )),
          ),
        )
        |> or_fail_with("expected HtmlDeleteFailed")
      }),
      it(
        "return HtmlSourceReadFailed when a source file cannot be read at finish",
        fn() {
          run_in_child(fn() {
            let _ = child_project("html_unreadable")
            add_source(
              "plain.erl",
              "-module(plain).\n-export([one/0]).\none() -> 1.\n",
            )
            compile_source("plain.erl", "debug_info")
            let config =
              coverage.new()
              |> coverage.no_lcov()
              |> coverage.html_path("build/html")
            case coverage.start(config) {
              Ok(session) -> {
                make_unreadable("plain.erl")
                coverage.finish(session)
              }
              Error(error) -> Error(error)
            }
          })
          |> should
          |> be_equal(
            Ok(
              Error(HtmlSourceReadFailed(
                "src/plain.erl",
                PermissionDenied("src/plain.erl"),
              )),
            ),
          )
          |> or_fail_with("expected HtmlSourceReadFailed")
        },
      ),
    ]),

    group("check_minimum", [
      it("passes when no minimum is set", fn() {
        coverage.check_minimum(
          config: coverage.new(),
          report: report_with_counts(1, 10),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected Ok without a minimum")
      }),
      it("passes when coverage equals the minimum exactly", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report_with_counts(4, 5),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected 80.0% to pass a minimum of 80.0")
      }),
      it("fails when coverage is just below the minimum", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report_with_counts(1999, 2500),
        )
        |> should
        |> be_equal(
          Error(BelowMinimumPercent(
            hit: 1999,
            total: 2500,
            minimum_percent: 80.0,
            lines_needed: 2000,
          )),
        )
        |> or_fail_with("expected 79.96% to fail a minimum of 80.0")
      }),
      it("rounds the minimum to one decimal place", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(72.56),
          report: report_with_counts(725, 1000),
        )
        |> should
        |> be_equal(
          Error(BelowMinimumPercent(
            hit: 725,
            total: 1000,
            minimum_percent: 72.6,
            lines_needed: 726,
          )),
        )
        |> or_fail_with("expected the minimum 72.56 to round to 72.6")
      }),
      it("passes when there are no executable lines", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report.new([]),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected Ok with no executable lines")
      }),
      it("returns InvalidMinimumPercent for a minimum out of range", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(120.0),
          report: report_with_counts(1, 1),
        )
        |> should
        |> be_equal(Error(InvalidMinimumPercent(120.0)))
        |> or_fail_with("expected InvalidMinimumPercent")
      }),
    ]),
  ])
}
