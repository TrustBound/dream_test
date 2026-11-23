//// The "Don't" example of rule 7 of STANDARDS.md: qualified references
//// where unqualified imports would work. It compiles and works, but it is
//// noisy.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import dream_test/unit.{describe, it}

// Bad: Noisy qualified references
pub fn nested_tree(
  name: String,
  nested: List(dream_types.Node(Nil)),
) -> dream_types.Tree(Nil) {
  let tree =
    dream_types.Tree(initial: Nil, name: name, tags: [], children: [
      dream_types.Group(name: "nested", tags: [], children: nested),
    ])
  tree
}

pub fn tests() {
  describe("STANDARDS.md rule 7, Bad: qualified references", [
    it("builds the tree", fn() {
      // Act
      let tree = nested_tree("root", [])

      // Assert
      tree
      |> should
      |> be_equal(
        dream_types.Tree(initial: Nil, name: "root", tags: [], children: [
          dream_types.Group(name: "nested", tags: [], children: []),
        ]),
      )
      |> or_fail_with("the tree should hold the nested group")
    }),
  ])
}
