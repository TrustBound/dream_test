//// README: Hook inheritance

import dream_test/assertions/should.{succeed}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/unit.{after_each, before_each, describe, group, it}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_each(fn(_) {
      io.println("1. outer setup")
      Ok(Nil)
    }),
    after_each(fn(_) {
      io.println("4. outer teardown")
      Ok(Nil)
    }),
    group("Inner", [
      before_each(fn(_) {
        io.println("2. inner setup")
        Ok(Nil)
      }),
      after_each(fn(_) {
        io.println("3. inner teardown")
        Ok(Nil)
      }),
      it("test", fn(_) {
        io.println("(test)")
        Ok(succeed())
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
