import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit_context.{describe, group, it, with_tags}

pub type Context {
  Context(counter: Int)
}

pub fn suite() {
  describe("Tagging context-aware tests", Context(counter: 0), [
    group("group tagged slow", [
      it("inherits the group tag", fn(_context: Context) { Ok(succeed()) }),
    ])
      |> with_tags(["slow"]),
    it("can tag an individual test", fn(_context: Context) { Ok(succeed()) })
      |> with_tags(["unit_context", "fast"]),
    it("untagged tests still work", fn(_context: Context) { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([suite()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
