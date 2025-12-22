import dream_test/matchers.{contain_string, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let results = runner.new([example_suite()]) |> runner.run()
      let report = bdd.format(results)

      report
      |> should
      |> contain_string("Example Suite")
      |> or_fail_with("Expected formatted report to include the suite name")
    }),
  ])
}
