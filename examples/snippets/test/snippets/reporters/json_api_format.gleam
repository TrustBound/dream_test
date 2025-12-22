import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/unit.{describe, it}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let results = runner.new([example_suite()]) |> runner.run()
  json.format(results)
}
