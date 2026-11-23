import dream_test/coverage/cobertura
import dream_test/coverage/report.{LineCoverage}

pub fn half_covered_xml() -> String {
  report.new([
    report.file("src/a.gleam", [
      LineCoverage(line: 1, calls: 1),
      LineCoverage(line: 2, calls: 0),
    ]),
  ])
  |> cobertura.render(timestamp: 0)
  // -> <?xml version="1.0" ?>
  //    <!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
  //    <coverage line-rate="0.5000" branch-rate="0" lines-covered="1" lines-valid="2" branches-covered="0" branches-valid="0" complexity="0" version="dream_test" timestamp="0">
  //      <sources>
  //        <source>.</source>
  //      </sources>
  //      <packages>
  //        <package name="src" line-rate="0.5000" branch-rate="0" complexity="0">
  //          <classes>
  //            <class name="a.gleam" filename="src/a.gleam" line-rate="0.5000" branch-rate="0" complexity="0">
  //              <methods/>
  //              <lines>
  //                <line number="1" hits="1"/>
  //                <line number="2" hits="0"/>
  //              </lines>
  //            </class>
  //          </classes>
  //        </package>
  //      </packages>
  //    </coverage>
}
