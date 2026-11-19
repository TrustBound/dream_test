import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{after_each, before_each, describe, group, it}
import gleam/io

pub fn tests() {
  describe("Enclosing", [
    before_each(fn() {
      io.println("1. enclosing before_each")
      Ok(Nil)
    }),
    after_each(fn() {
      io.println("4. enclosing after_each")
      Ok(Nil)
    }),
    group("Nested", [
      before_each(fn() {
        io.println("2. nested before_each")
        Ok(Nil)
      }),
      after_each(fn() {
        io.println("3. nested after_each")
        Ok(Nil)
      }),
      it("test body runs here", fn() {
        io.println("(test)")
        Ok(succeed())
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
