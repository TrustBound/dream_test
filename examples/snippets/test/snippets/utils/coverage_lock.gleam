//// Two coverage runs in one BEAM cannot measure the same module at the same
//// time. The snippet tests that start coverage on `src` take this lock, so
//// they run one at a time.

import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}

@external(erlang, "global", "trans")
fn global_transaction(lock: #(Atom, Pid), work: fn() -> a) -> a

/// Run `work` while no other snippet test measures `src`.
pub fn with_coverage_lock(work: fn() -> a) -> a {
  global_transaction(#(atom.create("snippets_coverage"), process.self()), work)
}
