@failure_showcase
Feature: Failure Showcase
  This feature file intentionally contains failing scenarios to exercise
  Dream Test's Gherkin output.

  Scenario: Failing assertion in a step
    Given a counter at 0
    When I increment the counter
    Then the counter should be 2

  Scenario: Undefined step
    Given a counter at 0
    When I do something undefined
    Then the counter should be 1


