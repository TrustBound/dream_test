@shopping
Feature: Shopping Cart
  As a customer I want to add items to my cart

  Background:
    Given I have an empty cart

  @smoke
  Scenario: Adding items
    When I add 3 items
    Then the cart should have 3 items

  Scenario: Adding multiple times
    When I add 2 items
    And I add 3 items
    Then the cart should have 5 items





