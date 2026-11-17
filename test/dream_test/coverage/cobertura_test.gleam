import dream_test/coverage/cobertura
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/string

fn full_report() {
  report.new([
    report.file("main.gleam", [LineCoverage(line: 2, calls: 1)]),
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 9, calls: 1),
    ]),
    report.file("src/app/types.gleam", []),
    report.file("src/a&b\"<c>'.gleam", [LineCoverage(line: 1, calls: 0)]),
  ])
}

fn full_xml() {
  string.concat([
    "<?xml version=\"1.0\" ?>\n",
    "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">\n",
    "<coverage line-rate=\"0.6000\" branch-rate=\"0\" lines-covered=\"3\" lines-valid=\"5\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"1700000000123\">\n",
    "  <sources>\n",
    "    <source>.</source>\n",
    "  </sources>\n",
    "  <packages>\n",
    "    <package name=\".\" line-rate=\"1.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    "        <class name=\"main.gleam\" filename=\"main.gleam\" line-rate=\"1.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"2\" hits=\"1\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "      </classes>\n",
    "    </package>\n",
    "    <package name=\"src\" line-rate=\"0.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    "        <class name=\"a&amp;b&quot;&lt;c&gt;&apos;.gleam\" filename=\"src/a&amp;b&quot;&lt;c&gt;&apos;.gleam\" line-rate=\"0.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"1\" hits=\"0\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "      </classes>\n",
    "    </package>\n",
    "    <package name=\"src.app\" line-rate=\"0.6666\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    "        <class name=\"cart.gleam\" filename=\"src/app/cart.gleam\" line-rate=\"0.6666\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "            <line number=\"3\" hits=\"2\"/>\n",
    "            <line number=\"4\" hits=\"0\"/>\n",
    "            <line number=\"9\" hits=\"1\"/>\n",
    "          </lines>\n",
    "        </class>\n",
    "        <class name=\"types.gleam\" filename=\"src/app/types.gleam\" line-rate=\"1.0000\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    "          </lines>\n",
    "        </class>\n",
    "      </classes>\n",
    "    </package>\n",
    "  </packages>\n",
    "</coverage>\n",
  ])
}

fn empty_xml() {
  string.concat([
    "<?xml version=\"1.0\" ?>\n",
    "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">\n",
    "<coverage line-rate=\"1.0000\" branch-rate=\"0\" lines-covered=\"0\" lines-valid=\"0\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"0\">\n",
    "  <sources>\n",
    "    <source>.</source>\n",
    "  </sources>\n",
    "  <packages>\n",
    "  </packages>\n",
    "</coverage>\n",
  ])
}

pub fn tests() {
  describe("dream_test/coverage/cobertura", [
    it(
      "renders a package per directory, a class per file and escapes XML",
      fn() {
        cobertura.render(report: full_report(), timestamp: 1_700_000_000_123)
        |> should
        |> be_equal(full_xml())
        |> or_fail_with("expected the full Cobertura XML")
      },
    ),
    it("renders an empty report with a line rate of 1.0000", fn() {
      cobertura.render(report: report.new([]), timestamp: 0)
      |> should
      |> be_equal(empty_xml())
      |> or_fail_with("expected the empty Cobertura XML")
    }),
  ])
}
