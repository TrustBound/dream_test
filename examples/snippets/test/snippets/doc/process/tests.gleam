import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/process/await_ready
import snippets/doc/process/await_some
import snippets/doc/process/counter_message
import snippets/doc/process/default_poll_config
import snippets/doc/process/get_count
import snippets/doc/process/port_selection
import snippets/doc/process/quick_poll_config
import snippets/doc/process/set_count
import snippets/doc/process/start_actor
import snippets/doc/process/start_counter
import snippets/doc/process/start_counter_with
import snippets/doc/process/unique_port

pub fn tests() {
  describe("Doc examples: process", [
    it("two_increments_count_two passes", fn() {
      // Act
      let result = start_counter.two_increments_count_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected two_increments_count_two to pass")
    }),
    it("messages_set_the_count passes", fn() {
      // Act
      let result = counter_message.messages_set_the_count()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected messages_set_the_count to pass")
    }),
    it("decrement_from_ten_gives_nine passes", fn() {
      // Act
      let result = start_counter_with.decrement_from_ten_gives_nine()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected decrement_from_ten_gives_nine to pass")
    }),
    it("one_increment_counts_one passes", fn() {
      // Act
      let result = get_count.one_increment_counts_one()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected one_increment_counts_one to pass")
    }),
    it("set_count_sets_forty_two passes", fn() {
      // Act
      let result = set_count.set_count_sets_forty_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected set_count_sets_forty_two to pass")
    }),
    it("port_holds_its_number passes", fn() {
      // Act
      let result = port_selection.port_holds_its_number()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected port_holds_its_number to pass")
    }),
    it("unique_port_is_in_the_safe_range passes", fn() {
      // Act
      let result = unique_port.unique_port_is_in_the_safe_range()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected unique_port_is_in_the_safe_range to pass")
    }),
    it("todos_keep_insertion_order passes", fn() {
      // Act
      let result = start_actor.todos_keep_insertion_order()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected todos_keep_insertion_order to pass")
    }),
    it("default_waits_five_seconds passes", fn() {
      // Act
      let result = default_poll_config.default_waits_five_seconds()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected default_waits_five_seconds to pass")
    }),
    it("quick_waits_one_second passes", fn() {
      // Act
      let result = quick_poll_config.quick_waits_one_second()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected quick_waits_one_second to pass")
    }),
    it("ready_when_check_is_true passes", fn() {
      // Act
      let result = await_ready.ready_when_check_is_true()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ready_when_check_is_true to pass")
    }),
    it("ready_with_the_ok_value passes", fn() {
      // Act
      let result = await_some.ready_with_the_ok_value()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ready_with_the_ok_value to pass")
    }),
  ])
}
