import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/result
import snippets/guides/context_store.{Get, Put, start_store, stop_store}

pub fn tests() {
  describe("The user store setup", [
    it("starts a store that keeps what it gets", fn() {
      // Arrange
      use store <- result.try(start_store())
      process.send(store, Put(7, "Grace"))

      // Act
      let found = process.call(store, 1000, Get(7, _))
      use Nil <- result.try(stop_store(store))

      // Assert
      found
      |> should
      |> be_equal(Ok("Grace"))
      |> or_fail_with("the new store should give back user 7")
    }),
    it("stops the store in the teardown", fn() {
      // Arrange
      use store <- result.try(start_store())

      // Act
      let stopped = stop_store(store)

      // Assert
      stopped
      |> should
      |> be_ok()
      |> be_equal(Nil)
      |> or_fail_with("the teardown should succeed")
    }),
  ])
}
