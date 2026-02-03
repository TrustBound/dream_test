Feature: Multiple Tables Test
  Testing that multiple steps can have tables

  Scenario: Two steps with tables
    Given the first table:
      | A | B |
      | 1 | 2 |
    When the second table:
      | X | Y |
      | 3 | 4 |
    Then both tables were received
