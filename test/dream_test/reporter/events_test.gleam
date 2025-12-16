import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/parallel
import dream_test/reporter/types as reporter_types
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{
  new_selector, new_subject, select, selector_receive, send,
}
import gleam/list
import gleam/result

pub fn tests() {
  describe("Reporter events", [
    it("emits RunStarted + one TestFinished per test + RunFinished", fn(_) {
      // Arrange
      let events = new_subject()
      let on_event = fn(event: reporter_types.ReporterEvent) {
        send(events, event)
      }

      let suite =
        describe("events", [
          it("t1", fn(_) { Ok(AssertionOk) }),
          it("t2", fn(_) { Ok(AssertionOk) }),
          it("t3", fn(_) { Ok(AssertionOk) }),
        ])

      let _results =
        parallel.run_suite_parallel_with_events(
          parallel.default_config(),
          suite,
          on_event,
        )

      // Act (read exactly 5 events: 1 started, 3 finished, 1 ended)
      let selector = new_selector() |> select(events)
      use e1 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 1")
      })
      use e2 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 2")
      })
      use e3 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 3")
      })
      use e4 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 4")
      })
      use e5 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 5")
      })

      let received = [e1, e2, e3, e4, e5]

      let started =
        list.filter(received, fn(e) {
          case e {
            reporter_types.RunStarted(_) -> True
            _ -> False
          }
        })
        |> list.length

      let finished =
        list.filter(received, fn(e) {
          case e {
            reporter_types.TestFinished(_, _, _) -> True
            _ -> False
          }
        })
        |> list.length

      let ended =
        list.filter(received, fn(e) {
          case e {
            reporter_types.RunFinished(_, _) -> True
            _ -> False
          }
        })
        |> list.length

      // Assert (one assertion)
      [started, finished, ended]
      |> should()
      |> equal([1, 3, 1])
      |> or_fail_with(
        "should emit (1 RunStarted, 3 TestFinished, 1 RunFinished)",
      )
    }),

    it("starts with RunStarted and ends with RunFinished", fn(_) {
      // Arrange
      let events = new_subject()
      let on_event = fn(event: reporter_types.ReporterEvent) {
        send(events, event)
      }

      let suite =
        describe("events", [
          it("t1", fn(_) { Ok(AssertionOk) }),
          it("t2", fn(_) { Ok(AssertionOk) }),
          it("t3", fn(_) { Ok(AssertionOk) }),
        ])

      let _results =
        parallel.run_suite_parallel_with_events(
          parallel.default_config(),
          suite,
          on_event,
        )

      // Act
      let selector = new_selector() |> select(events)
      use e1 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 1")
      })
      use _e2 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 2")
      })
      use _e3 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 3")
      })
      use _e4 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 4")
      })
      use e5 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 5")
      })

      // Assert (one assertion, value-based)
      [e1, e5]
      |> should()
      |> equal([reporter_types.RunStarted(3), reporter_types.RunFinished(3, 3)])
      |> or_fail_with(
        "Events should start with RunStarted(3) and end with RunFinished(3,3)",
      )
    }),

    it("emits TestFinished.completed values as 1..N in order", fn(_) {
      // Arrange
      let events = new_subject()
      let on_event = fn(event: reporter_types.ReporterEvent) {
        send(events, event)
      }

      let suite =
        describe("events", [
          it("t1", fn(_) { Ok(AssertionOk) }),
          it("t2", fn(_) { Ok(AssertionOk) }),
          it("t3", fn(_) { Ok(AssertionOk) }),
        ])

      let _results =
        parallel.run_suite_parallel_with_events(
          parallel.default_config(),
          suite,
          on_event,
        )

      // Act
      let selector = new_selector() |> select(events)
      use e1 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 1")
      })
      use e2 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 2")
      })
      use e3 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 3")
      })
      use e4 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 4")
      })
      use e5 <- result.try(case selector_receive(selector, 1000) {
        Ok(e) -> Ok(e)
        Error(Nil) -> Error("timeout waiting for event 5")
      })

      let received = [e1, e2, e3, e4, e5]
      let completed_values =
        list.fold(received, [], fn(acc, event) {
          case event {
            reporter_types.TestFinished(completed: c, total: _t, result: _r) -> [
              c,
              ..acc
            ]
            _ -> acc
          }
        })
        |> list.reverse

      // Assert (one assertion)
      completed_values
      |> should()
      |> equal([1, 2, 3])
      |> or_fail_with("TestFinished.completed should be 1..3 in order")
    }),
  ])
}
