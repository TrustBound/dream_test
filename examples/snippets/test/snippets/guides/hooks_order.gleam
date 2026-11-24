import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it,
}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_all(fn() {
      io.println("outer before_all")
      Ok(Nil)
    }),
    before_each(fn() {
      io.println("  outer before_each")
      Ok(Nil)
    }),
    after_each(fn() {
      io.println("  outer after_each")
      Ok(Nil)
    }),
    after_all(fn() {
      io.println("outer after_all")
      Ok(Nil)
    }),
    group("Inner", [
      before_each(fn() {
        io.println("    inner before_each")
        Ok(Nil)
      }),
      after_each(fn() {
        io.println("    inner after_each")
        Ok(Nil)
      }),
      it("runs in the middle", fn() {
        io.println("      the test body")
        Ok(succeed())
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
