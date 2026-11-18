//// A timeout for tests that start another BEAM or an operating system
//// program. Such a test takes a few seconds, and more on a busy machine,
//// so the default timeout of 5 seconds is too near. The timeout is a
//// safety limit only: a passing test never comes near it.

import dream_test/types.{type Node, type Root, Group, Root, Test}
import gleam/list
import gleam/option.{Some}

/// 60 seconds.
pub const child_timeout_ms = 60_000

/// Give every test in `node` the timeout `child_timeout_ms`.
pub fn with_child_timeout(node: Node(context)) -> Node(context) {
  case node {
    Group(..) ->
      Group(..node, children: list.map(node.children, with_child_timeout))
    Test(..) -> Test(..node, timeout_ms: Some(child_timeout_ms))
    other -> other
  }
}

/// Give every test in `suite` the timeout `child_timeout_ms`.
pub fn suite_with_child_timeout(suite: Root(context)) -> Root(context) {
  Root(..suite, children: list.map(suite.children, with_child_timeout))
}
