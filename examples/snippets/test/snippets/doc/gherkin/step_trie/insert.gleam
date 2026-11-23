import dream_test/gherkin/step_trie.{type StepTrie}
import dream_test/gherkin/types.{GivenPhase}

pub fn item_count_trie() -> Result(StepTrie(String), String) {
  step_trie.new()
  |> step_trie.insert(
    phase: GivenPhase,
    pattern: "I have {int} items",
    handler: "count",
  )
}
