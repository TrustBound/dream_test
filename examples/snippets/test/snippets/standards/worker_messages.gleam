//// The messages and helpers that the two process start examples of rule 2
//// of STANDARDS.md use.

pub type WorkerMessage(a) {
  TestCompleted(a)
  TestCrashed(String)
}

/// Runs `run` with `input`. The examples do not crash, so it always
/// returns `Ok`.
pub fn run_catching(run: fn(input) -> a, input: input) -> Result(a, String) {
  Ok(run(input))
}

pub fn caught_message(result: Result(a, String)) -> WorkerMessage(a) {
  case result {
    Ok(value) -> TestCompleted(value)
    Error(message) -> TestCrashed(message)
  }
}
