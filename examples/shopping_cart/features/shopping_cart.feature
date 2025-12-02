@shopping @e2e
Feature: Shopping Cart
  As a customer
  I want to manage items in my shopping cart
  So that I can purchase products I need

  Background:
    Given I have an empty cart

  @happy-path
  Scenario: Adding a single item to the cart
    When I add 2 apples to the cart
    Then the cart should contain 2 items
    And the subtotal should be $3.00

  @happy-path
  Scenario: Adding multiple different items
    When I add 1 apple to the cart
    And I add 3 bananas to the cart
    Then the cart should contain 4 items
    And the subtotal should be $3.75

  @quantity
  Scenario: Updating item quantity
    Given I add 2 apples to the cart
    When I update the apples quantity to 5
    Then the cart should contain 5 items
    And the subtotal should be $7.50

  @removal
  Scenario: Removing an item from the cart
    Given I add 2 apples to the cart
    And I add 1 banana to the cart
    When I remove apples from the cart
    Then the cart should contain 1 items
    And the subtotal should be $0.75

  @discount
  Scenario: Applying a percentage discount
    Given I add 4 apples to the cart
    When I apply a 10% discount
    Then the subtotal should be $6.00
    And the discount should be $0.60
    And the total should be $5.40

  @discount
  Scenario: Applying a fixed amount discount
    Given I add 2 oranges to the cart
    When I apply a $1.00 discount
    Then the subtotal should be $4.00
    And the discount should be $1.00
    And the total should be $3.00

  @checkout
  Scenario: Successful checkout
    Given I add 1 apple to the cart
    And I add 2 bananas to the cart
    When I checkout
    Then the checkout should succeed
    And the order total should be $3.00

  @error
  Scenario: Cannot checkout an empty cart
    When I checkout
    Then the checkout should fail with "cart is empty"

  @error
  Scenario: Cannot add zero items
    When I try to add 0 apples to the cart
    Then the operation should fail with "invalid quantity"
