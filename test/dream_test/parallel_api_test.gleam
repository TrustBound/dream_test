import dream_test/runner
import dream_test/timing
import dream_test/types.{AssertionFailed, AssertionFailure, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string

pub fn tests() {
  describe("dream_test/parallel", [
    it("runs tests in parallel and keeps deterministic ordering", fn() {
      let suite =
        describe("p", [
          it("t1", fn() {
            process.sleep(100)
            Ok(AssertionOk)
          }),
          it("t2", fn() {
            process.sleep(100)
            Ok(AssertionOk)
          }),
          it("t3", fn() {
            process.sleep(100)
            Ok(AssertionOk)
          }),
          it("t4", fn() {
            process.sleep(100)
            Ok(AssertionOk)
          }),
        ])

      let t_serial_start = timing.now_ms()
      let serial_results =
        runner.new([suite])
        |> runner.max_concurrency(1)
        |> runner.run()
      let t_serial = timing.now_ms() - t_serial_start

      let t_par_start = timing.now_ms()
      let par_results =
        runner.new([suite])
        |> runner.max_concurrency(4)
        |> runner.run()
      let t_par = timing.now_ms() - t_par_start

      let _serial_names = list.map(serial_results, fn(r) { r.name })
      let par_names = list.map(par_results, fn(r) { r.name })

      let order_assertion = case par_names == ["t1", "t2", "t3", "t4"] {
        True -> AssertionOk
        False ->
          AssertionFailed(AssertionFailure(
            operator: "order",
            message: "expected deterministic order, got "
              <> string.inspect(par_names),
            payload: None,
          ))
      }

      case order_assertion {
        AssertionOk ->
          case t_serial > t_par + 150 {
            True -> Ok(AssertionOk)
            False ->
              Ok(
                AssertionFailed(AssertionFailure(
                  operator: "parallel",
                  message: "expected parallel run to be significantly faster, serial="
                    <> int.to_string(t_serial)
                    <> "ms parallel="
                    <> int.to_string(t_par)
                    <> "ms",
                  payload: None,
                )),
              )
          }
        _ -> Ok(order_assertion)
      }
    }),
  ])
}
