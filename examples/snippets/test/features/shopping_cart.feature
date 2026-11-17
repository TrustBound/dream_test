Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
