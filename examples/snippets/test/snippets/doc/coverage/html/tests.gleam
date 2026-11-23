import dream_test/coverage
import dream_test/matchers.{be_equal, match_snapshot, or_fail_with, should}
import dream_test/unit.{describe, it}
import snippets/doc/coverage/html/combined
import snippets/doc/coverage/html/index
import snippets/doc/coverage/html/module
import snippets/doc/coverage/html/module_import_style
import snippets/doc/coverage/html/page_path
import snippets/doc/coverage/html/source_page

pub fn tests() {
  describe("Doc examples: coverage/html", [
    it("write_html_pages gives the documented result", fn() {
      // Act
      let result = module.write_html_pages()

      // Assert
      result
      |> should
      |> be_equal(
        coverage.new()
        |> coverage.html_path("build/coverage/html")
        |> coverage.html_file("build/coverage/all.html"),
      )
      |> or_fail_with("expected write_html_pages to give the documented result")
    }),
    it("page_of_cart_file gives the documented result", fn() {
      // Act
      let result = module_import_style.page_of_cart_file()

      // Assert
      result
      |> should
      |> be_equal("files/src/app/cart.gleam.html")
      |> or_fail_with(
        "expected page_of_cart_file to give the documented result",
      )
    }),
    it("index_page gives the page in its snapshot", fn() {
      // Act
      let page = index.index_page()

      // Assert
      page
      |> should
      |> match_snapshot("./test/snapshots/doc_coverage_html_index_page.snap")
      |> or_fail_with(
        "expected index_page to give the page in doc_coverage_html_index_page.snap",
      )
    }),
    it("combined_page gives the page in its snapshot", fn() {
      // Act
      let page = combined.combined_page()

      // Assert
      page
      |> should
      |> match_snapshot("./test/snapshots/doc_coverage_html_combined_page.snap")
      |> or_fail_with(
        "expected combined_page to give the page in doc_coverage_html_combined_page.snap",
      )
    }),
    it("source_page_of_file gives the page in its snapshot", fn() {
      // Act
      let page = source_page.source_page_of_file()

      // Assert
      page
      |> should
      |> match_snapshot(
        "./test/snapshots/doc_coverage_html_source_page_of_file.snap",
      )
      |> or_fail_with(
        "expected source_page_of_file to give the page in doc_coverage_html_source_page_of_file.snap",
      )
    }),
    it("page_path_with_space gives the documented result", fn() {
      // Act
      let result = page_path.page_path_with_space()

      // Assert
      result
      |> should
      |> be_equal("files/src/app/my~20cart.gleam.html")
      |> or_fail_with(
        "expected page_path_with_space to give the documented result",
      )
    }),
  ])
}
