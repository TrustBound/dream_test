import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}
import gleam/erlang/process as erlang_process

pub fn messages_set_the_count() -> Result(AssertionResult, String) {
  let counter = process.start_counter()

  erlang_process.send(counter, process.Increment)
  erlang_process.send(counter, process.SetCount(10))

  process.get_count(counter)
  |> should
  |> be_equal(10)
  |> or_fail_with("expected counter to be 10 after SetCount")
}
