@stock
Feature: Stock control
  The shop sells items from its stock.

  Background:
    Given the shop is open

  Rule: An item can be sold only when it is in stock

    Background:
      And the stock holds 5 items

    Example: Sell from stock
      When I sell 2 items
      Then the stock holds 3 items

    Scenario Outline: Sell different amounts
      When I sell <sold> items
      Then the stock holds <left> items

      @small
      Examples: Small orders
        | sold | left |
        | 1    | 4    |
        | 2    | 3    |

      @large
      Scenarios: Large orders
        | sold | left |
        | 5    | 0    |

  Rule: A sold-out shop sells nothing

    Background:
      * the stock holds 0 items

    Scenario: Nothing to sell
      Then the stock holds 0 items
