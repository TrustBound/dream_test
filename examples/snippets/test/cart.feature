@shopping
Feature: Shopping Cart
  As a customer I want to add items to my cart

  Background:
    Given the server is running

  @smoke
  Scenario: Adding items
    Given the cart is empty
    When I add 3 items
    Then the cart should have 3 items

  Scenario: Adding multiple times
    Given the cart is empty
    When I add 2 items
    And I add 3 items
    Then the cart should have 5 items

