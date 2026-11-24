//// Two coverage runs in one BEAM cannot measure the same module at the same
//// time. The snippet tests that start coverage on `src` take this lock, so
//// they run one at a time.
////
//// The lock is a process that grants it in the order that the tests ask
//// and monitors the holder, so a test that stops frees it. A waiting test
//// gets the lock as soon as it is free, with no random wait.

/// Run `work` while no other snippet test measures `src`.
pub fn with_coverage_lock(work: fn() -> a) -> a {
  with_lock(work)
}

@external(erlang, "snippets_coverage_lock_ffi", "with_lock")
fn with_lock(work: fn() -> a) -> a
