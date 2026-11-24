Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 1 more items
    Then I should have 5 items total

  Scenario: Removing items
    Given I have 3 items in my cart
    When I remove 1 item
    Then I should have 2 items total

  Scenario: Breaking the cart
    Given I have 3 items in my cart
    When the cart breaks
    Then I should have 3 items total
