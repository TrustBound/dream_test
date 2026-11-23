import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/string
import snippets/doc/coverage/cobertura/module
import snippets/doc/coverage/cobertura/module_import_style
import snippets/doc/coverage/cobertura/render

pub fn tests() {
  describe("Doc examples: coverage/cobertura", [
    it("write_cobertura_xml gives the documented result", fn() {
      // Act
      let result = module.write_cobertura_xml()

      // Assert
      result
      |> should
      |> be_equal(
        coverage.new()
        |> coverage.cobertura_path("build/coverage/cobertura.xml"),
      )
      |> or_fail_with(
        "expected write_cobertura_xml to give the documented result",
      )
    }),
    it("empty_report_xml gives the documented result", fn() {
      // Act
      let result = module_import_style.empty_report_xml()

      // Assert
      result
      |> should
      |> be_equal(
        string.join(
          [
            "<?xml version=\"1.0\" ?>",
            "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">",
            "<coverage line-rate=\"1.0000\" branch-rate=\"0\" lines-covered=\"0\" lines-valid=\"0\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"0\">",
            "  <sources>",
            "    <source>.</source>",
            "  </sources>",
            "  <packages>",
            "  </packages>",
            "</coverage>",
          ],
          "\n",
        )
        <> "\n",
      )
      |> or_fail_with("expected empty_report_xml to give the documented result")
    }),
    it("half_covered_xml gives the documented result", fn() {
      // Act
      let result = render.half_covered_xml()

      // Assert
      result
      |> should
      |> be_equal(
        string.join(
          [
            "<?xml version=\"1.0\" ?>",
            "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">",
            "<coverage line-rate=\"0.5000\" branch-rate=\"0\" lines-covered=\"1\" lines-valid=\"2\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"0\">",
            "  <sources>",
            "    <source>.</source>",
            "  </sources>",
            "  <packages>",
            "    <package name=\"src\" line-rate=\"0.5000\" branch-rate=\"0\" complexity=\"0\">",
            "      <classes>",
            "        <class name=\"a.gleam\" filename=\"src/a.gleam\" line-rate=\"0.5000\" branch-rate=\"0\" complexity=\"0\">",
            "          <methods/>",
            "          <lines>",
            "            <line number=\"1\" hits=\"1\"/>",
            "            <line number=\"2\" hits=\"0\"/>",
            "          </lines>",
            "        </class>",
            "      </classes>",
            "    </package>",
            "  </packages>",
            "</coverage>",
          ],
          "\n",
        )
        <> "\n",
      )
      |> or_fail_with("expected half_covered_xml to give the documented result")
    }),
  ])
}
