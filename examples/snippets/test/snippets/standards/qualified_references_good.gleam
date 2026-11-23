//// The "Do" example of rule 7 of STANDARDS.md: unqualified imports.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type Node, type Tree, Group, Tree}
import dream_test/unit.{describe, it}

// Good: Clean unqualified usage
pub fn nested_tree(name: String, nested: List(Node(Nil))) -> Tree(Nil) {
  let tree =
    Tree(initial: Nil, name: name, tags: [], children: [
      Group(name: "nested", tags: [], children: nested),
    ])
  tree
}

pub fn tests() {
  describe("STANDARDS.md rule 7, Good: unqualified references", [
    it("builds the tree", fn() {
      // Act
      let tree = nested_tree("root", [])

      // Assert
      tree
      |> should
      |> be_equal(
        Tree(initial: Nil, name: "root", tags: [], children: [
          Group(name: "nested", tags: [], children: []),
        ]),
      )
      |> or_fail_with("the tree should hold the nested group")
    }),
  ])
}
