//// Unit test failures for the failure showcase example.

import dream_test/matchers.{be_equal, be_true, or_fail_with, should, succeed}
import dream_test/unit.{after_each, before_all, before_each, describe, group, it}
import gleam/erlang/process

pub fn tests() {
  describe("Failure Showcase (unit)", [
    it("assertion payload: equality mismatch", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional equality failure: 1 should equal 2")
    }),

    it("assertion payload: boolean mismatch", fn() {
      False
      |> should
      |> be_true()
      |> or_fail_with("intentional boolean failure: expected True")
    }),

    it("explicit Error(...) from test body", fn() {
      Error("intentional Error(...) from test body")
    }),

    it("sandbox crash (panic)", fn() {
      panic as "intentional crash for failure showcase"
    }),

    it("timeout (default timeout is set low in the runner)", fn() {
      process.sleep(50)
      Ok(succeed())
    }),

    group("hook failure: before_all", [
      before_all(fn() { Error("intentional before_all failure") }),
      it("test 1 (will not run, should be marked failed)", fn() {
        Ok(succeed())
      }),
      it("test 2 (will not run, should be marked failed)", fn() {
        Ok(succeed())
      }),
    ]),

    group("hook failure: before_each", [
      before_each(fn() { Error("intentional before_each failure") }),
      it("will not run, should be marked failed", fn() { Ok(succeed()) }),
    ]),

    group("hook failure: after_each", [
      after_each(fn() { Error("intentional after_each failure") }),
      it("runs but fails during teardown", fn() { Ok(succeed()) }),
    ]),
  ])
}
