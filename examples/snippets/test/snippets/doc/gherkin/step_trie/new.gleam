import dream_test/gherkin/step_trie.{type StepTrie}
import dream_test/gherkin/types.{GivenPhase}

pub fn empty_cart_trie() -> Result(StepTrie(String), String) {
  step_trie.new()
  |> step_trie.insert(
    phase: GivenPhase,
    pattern: "I have an empty cart",
    handler: "empty",
  )
}
