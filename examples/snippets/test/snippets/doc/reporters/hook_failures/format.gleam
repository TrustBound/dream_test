import dream_test/reporters/hook_failures
import dream_test/types

pub fn stopped_setup_section() -> String {
  hook_failures.format([
    types.SetupStopped(
      setup: types.BeforeAllHook,
      path: ["root"],
      reason: "Boom",
      not_run: [["root", "b"], ["root", "c"]],
    ),
  ])
  // -> "Setup and teardown failures:\n  before_all in \"root\" stopped: the process that keeps its setup alive exited with Boom.\n    These tests had not started and were not run:\n      root > b\n      root > c\n"
}
