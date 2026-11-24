//// The "Pattern matching blocks" example of STANDARDS.md: a branch with
//// more than one expression needs curly braces.

import dream_test/types.{type Node, Group, Test, full_name}
import gleam/list

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}

pub fn collect_test_names(
  name_prefix: List(String),
  nodes: List(Node(Nil)),
  names: List(List(String)),
) -> List(List(String)) {
  case nodes {
    [] -> names
    [node, ..rest] ->
      collect_test_names(
        name_prefix,
        rest,
        list.append(names, names_of_node(name_prefix, node)),
      )
  }
}

fn names_of_node(
  name_prefix: List(String),
  node: Node(Nil),
) -> List(List(String)) {
  case node {
    Test(name: name, ..) -> [full_name(groups: name_prefix, name: name)]

    Group(name: name, tests: tests, ..) -> {
      let new_prefix = list.append(name_prefix, [name])
      collect_test_names(new_prefix, tests, [])
    }

    _ -> []
  }
}

pub fn tests() {
  describe("STANDARDS.md: a branch with curly braces", [
    it("collects the full names of the tests", fn() {
      // Arrange
      let nodes = [
        it("adds", fn() { Ok(succeed()) }),
        Group(name: "nested", tags: [], tests: [
          it("subtracts", fn() { Ok(succeed()) }),
        ]),
      ]

      // Act
      let names = collect_test_names(["math"], nodes, [])

      // Assert
      names
      |> should
      |> be_equal([["math", "adds"], ["math", "nested", "subtracts"]])
      |> or_fail_with("the names should have their group path")
    }),
  ])
}
