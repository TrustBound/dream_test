import dream_test/types

pub fn drop_schema_failure() -> types.HookFailure {
  types.TeardownFailed(
    hook: types.AfterAllHook,
    path: ["Database"],
    message: "could not drop the test schema",
  )
}
