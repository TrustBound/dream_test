//// Black-box tests of `dream_test/coverage/html`.

import dream_test/coverage/html
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/dict
import gleam/option.{None, Some}
import gleam/string

fn style_rules() {
  [
    ":root { color-scheme: light dark; --text: #1f2328; --background: #ffffff; --border: #d0d7de; --muted: #59636e; --hit: #dafbe1; --missed: #ffebe9; --ignored: #eaeef2; --complete: #1a7f37; --partial: #9a6700; --low: #cf222e; }",
    "@media (prefers-color-scheme: dark) { :root { --text: #e6edf3; --background: #0d1117; --border: #30363d; --muted: #9198a1; --hit: #12261e; --missed: #301418; --ignored: #1c2128; --complete: #3fb950; --partial: #d29922; --low: #f85149; } }",
    "body { margin: 16px; font-family: system-ui, sans-serif; color: var(--text); background: var(--background); }",
    "a { color: inherit; }",
    "table { border-collapse: collapse; }",
    "th, td { padding: 2px 8px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }",
    ".number { text-align: right; }",
    ".complete { color: var(--complete); }",
    ".partial { color: var(--partial); }",
    ".low { color: var(--low); }",
    ".source td { border-bottom: 0; font-family: ui-monospace, monospace; white-space: pre; }",
    ".source td.number { color: var(--muted); }",
    "tr.hit { background: var(--hit); }",
    "tr.missed { background: var(--missed); }",
    "tr.ignored { background: var(--ignored); }",
  ]
}

fn expected_document(title: String, body: List(String)) -> String {
  string.concat([
    "<!DOCTYPE html>\n",
    "<html lang=\"en\">\n",
    "<head>\n",
    "<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
    "<title>",
    title,
    "</title>\n",
    "<style>\n",
    string.join(style_rules(), "\n"),
    "\n</style>\n",
    "</head>\n",
    "<body>\n",
    string.concat(body),
    "</body>\n",
    "</html>\n",
  ])
}

/// The text after `<body>`, so a test can skip the head.
fn body(document: String) -> String {
  case string.split_once(document, "<body>\n") {
    Ok(#(_, rest)) -> rest
    Error(Nil) -> document
  }
}

fn table_header() {
  "<thead><tr><th>File</th><th class=\"number\">Lines</th><th class=\"number\">Cover</th><th>Missing</th><th>Excluded</th></tr></thead>\n"
}

fn source_header() {
  "<thead><tr><th class=\"number\">Line</th><th class=\"number\">Hits</th><th>Source</th></tr></thead>\n"
}

fn full_report() {
  report.new([
    report.file("src/a&b's.gleam", [LineCoverage(line: 1, calls: 1)]),
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 5, calls: 0),
      LineCoverage(line: 9, calls: 0),
    ])
      |> report.add_ignored_ranges([
        report.ignored_range(
          first_line: 40,
          last_line: 44,
          reason: Some("debug <only>"),
        ),
        report.ignored_range(first_line: 71, last_line: 71, reason: None),
      ]),
    report.file("src/app/types.gleam", []),
    report.file("src/half.gleam", [
      LineCoverage(line: 1, calls: 1),
      LineCoverage(line: 2, calls: 0),
    ]),
  ])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/gen.gleam",
      pattern: "src/gen*",
      reason: Some("\"generated\""),
    ),
  ])
}

fn full_index_body() {
  string.concat([
    "<h1>Coverage</h1>\n",
    "<table>\n",
    table_header(),
    "<tbody>\n",
    "<tr><td><a href=\"files/src/a~26b~27s.gleam.html\">src/a&amp;b&apos;s.gleam</a></td><td class=\"number\">1/1</td><td class=\"number complete\">100.0%</td><td></td><td></td></tr>\n",
    "<tr><td><a href=\"files/src/app/cart.gleam.html\">src/app/cart.gleam</a></td><td class=\"number\">1/4</td><td class=\"number low\">25.0%</td><td>4-5, 9</td><td>40-44 (debug &lt;only&gt;), 71</td></tr>\n",
    "<tr><td><a href=\"files/src/app/types.gleam.html\">src/app/types.gleam</a></td><td class=\"number\">0/0</td><td class=\"number complete\">-</td><td></td><td></td></tr>\n",
    "<tr><td><a href=\"files/src/half.gleam.html\">src/half.gleam</a></td><td class=\"number\">1/2</td><td class=\"number partial\">50.0%</td><td>2</td><td></td></tr>\n",
    "<tr><td>src/gen.gleam</td><td></td><td></td><td></td><td>excluded: matches src/gen* (&quot;generated&quot;)</td></tr>\n",
    "</tbody>\n",
    "<tfoot><tr><td>Total</td><td class=\"number\">3/7</td><td class=\"number low\">42.8%</td><td></td><td></td></tr>\n",
    "</tfoot>\n",
    "</table>\n",
    "<p>Excluded: 1 file, 6 lines in 1 file</p>\n",
    "</body>\n",
    "</html>\n",
  ])
}

fn cart_file() {
  report.file("src/app/cart.gleam", [
    LineCoverage(line: 2, calls: 3),
    LineCoverage(line: 3, calls: 0),
    LineCoverage(line: 9, calls: 0),
  ])
  |> report.add_ignored_ranges([
    report.ignored_range(first_line: 4, last_line: 5, reason: Some("debug <x>")),
    report.ignored_range(first_line: 6, last_line: 6, reason: None),
  ])
}

fn cart_source() {
  "fn a() {\n  \"<b>\" & 'c'\n  x\n  y\n  z\n  w\n}\n"
}

fn cart_page_body() {
  string.concat([
    "<p><a href=\"../../../index.html\">All files</a></p>\n",
    "<h1>src/app/cart.gleam</h1>\n",
    "<p>Lines: 1/3. Cover: <span class=\"low\">33.3%</span>.</p>\n",
    "<p>Ignored: 4-5 (debug &lt;x&gt;), 6</p>\n",
    "<table class=\"source\">\n",
    source_header(),
    "<tbody>\n",
    "<tr class=\"not-executable\"><td class=\"number\">1</td><td class=\"number\"></td><td>fn a() {</td></tr>\n",
    "<tr class=\"hit\"><td class=\"number\">2</td><td class=\"number\">3</td><td>  &quot;&lt;b&gt;&quot; &amp; &apos;c&apos;</td></tr>\n",
    "<tr class=\"missed\"><td class=\"number\">3</td><td class=\"number\">0</td><td>  x</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored: debug &lt;x&gt;\"><td class=\"number\">4</td><td class=\"number\">ignored</td><td>  y</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored: debug &lt;x&gt;\"><td class=\"number\">5</td><td class=\"number\">ignored</td><td>  z</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored\"><td class=\"number\">6</td><td class=\"number\">ignored</td><td>  w</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">7</td><td class=\"number\"></td><td>}</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">8</td><td class=\"number\"></td><td></td></tr>\n",
    "<tr class=\"missed\"><td class=\"number\">9</td><td class=\"number\">0</td><td></td></tr>\n",
    "</tbody>\n",
    "</table>\n",
    "</body>\n",
    "</html>\n",
  ])
}

/// The text after the summary table of a combined page: the excluded
/// summary and the sections.
fn after_summary_table(document: String) -> String {
  case string.split_once(document, "</table>\n") {
    Ok(#(_, rest)) -> rest
    Error(Nil) -> document
  }
}

/// The cart page body as a section of the combined page.
fn cart_section() {
  string.concat([
    "<section id=\"file-src~2Fapp~2Fcart.gleam\">\n",
    "<h2>src/app/cart.gleam</h2>\n",
    "<p>Lines: 1/3. Cover: <span class=\"low\">33.3%</span>.</p>\n",
    "<p>Ignored: 4-5 (debug &lt;x&gt;), 6</p>\n",
    "<table class=\"source\">\n",
    source_header(),
    "<tbody>\n",
    "<tr class=\"not-executable\"><td class=\"number\">1</td><td class=\"number\"></td><td>fn a() {</td></tr>\n",
    "<tr class=\"hit\"><td class=\"number\">2</td><td class=\"number\">3</td><td>  &quot;&lt;b&gt;&quot; &amp; &apos;c&apos;</td></tr>\n",
    "<tr class=\"missed\"><td class=\"number\">3</td><td class=\"number\">0</td><td>  x</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored: debug &lt;x&gt;\"><td class=\"number\">4</td><td class=\"number\">ignored</td><td>  y</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored: debug &lt;x&gt;\"><td class=\"number\">5</td><td class=\"number\">ignored</td><td>  z</td></tr>\n",
    "<tr class=\"ignored\" title=\"ignored\"><td class=\"number\">6</td><td class=\"number\">ignored</td><td>  w</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">7</td><td class=\"number\"></td><td>}</td></tr>\n",
    "<tr class=\"not-executable\"><td class=\"number\">8</td><td class=\"number\"></td><td></td></tr>\n",
    "<tr class=\"missed\"><td class=\"number\">9</td><td class=\"number\">0</td><td></td></tr>\n",
    "</tbody>\n",
    "</table>\n",
    "</section>\n",
  ])
}

pub fn tests() {
  describe("dream_test/coverage/html", [
    group("index", [
      it("renders a complete document for a small report", fn() {
        report.new([
          report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
        ])
        |> html.index()
        |> should
        |> be_equal(
          expected_document("Coverage", [
            "<h1>Coverage</h1>\n",
            "<table>\n",
            table_header(),
            "<tbody>\n",
            "<tr><td><a href=\"files/src/a.gleam.html\">src/a.gleam</a></td><td class=\"number\">1/1</td><td class=\"number complete\">100.0%</td><td></td><td></td></tr>\n",
            "</tbody>\n",
            "<tfoot><tr><td>Total</td><td class=\"number\">1/1</td><td class=\"number complete\">100.0%</td><td></td><td></td></tr>\n",
            "</tfoot>\n",
            "</table>\n",
          ]),
        )
        |> or_fail_with("expected the index document")
      }),
      it(
        "renders links, colours, missing and ignored lines, excluded files and totals",
        fn() {
          html.index(full_report())
          |> body()
          |> should
          |> be_equal(full_index_body())
          |> or_fail_with("expected the full index body")
        },
      ),
    ]),
    group("source_page", [
      it("renders a complete document for a small file", fn() {
        report.file("a.gleam", [LineCoverage(line: 1, calls: 1)])
        |> html.source_page(source: "x")
        |> should
        |> be_equal(
          expected_document("a.gleam - Coverage", [
            "<p><a href=\"../index.html\">All files</a></p>\n",
            "<h1>a.gleam</h1>\n",
            "<p>Lines: 1/1. Cover: <span class=\"complete\">100.0%</span>.</p>\n",
            "<table class=\"source\">\n",
            source_header(),
            "<tbody>\n",
            "<tr class=\"hit\"><td class=\"number\">1</td><td class=\"number\">1</td><td>x</td></tr>\n",
            "</tbody>\n",
            "</table>\n",
          ]),
        )
        |> or_fail_with("expected the source page document")
      }),
      it(
        "marks hit, missed, ignored and not executable lines, and lines after the source",
        fn() {
          html.source_page(file: cart_file(), source: cart_source())
          |> body()
          |> should
          |> be_equal(cart_page_body())
          |> or_fail_with("expected the cart page body")
        },
      ),
    ]),
    group("combined", [
      it(
        "renders the table with section links, then a section per file in report order",
        fn() {
          report.new([
            report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
            report.file("src/my b~.gleam", [LineCoverage(line: 1, calls: 0)]),
          ])
          |> html.combined(sources: dict.from_list([#("src/a.gleam", "x")]))
          |> should
          |> be_equal(
            expected_document("Coverage", [
              "<h1>Coverage</h1>\n",
              "<table>\n",
              table_header(),
              "<tbody>\n",
              "<tr><td><a href=\"#file-src~2Fa.gleam\">src/a.gleam</a></td><td class=\"number\">1/1</td><td class=\"number complete\">100.0%</td><td></td><td></td></tr>\n",
              "<tr><td><a href=\"#file-src~2Fmy~20b~7E.gleam\">src/my b~.gleam</a></td><td class=\"number\">0/1</td><td class=\"number low\">0.0%</td><td>1</td><td></td></tr>\n",
              "</tbody>\n",
              "<tfoot><tr><td>Total</td><td class=\"number\">1/2</td><td class=\"number partial\">50.0%</td><td></td><td></td></tr>\n",
              "</tfoot>\n",
              "</table>\n",
              "<section id=\"file-src~2Fa.gleam\">\n",
              "<h2>src/a.gleam</h2>\n",
              "<p>Lines: 1/1. Cover: <span class=\"complete\">100.0%</span>.</p>\n",
              "<table class=\"source\">\n",
              source_header(),
              "<tbody>\n",
              "<tr class=\"hit\"><td class=\"number\">1</td><td class=\"number\">1</td><td>x</td></tr>\n",
              "</tbody>\n",
              "</table>\n",
              "</section>\n",
              "<section id=\"file-src~2Fmy~20b~7E.gleam\">\n",
              "<h2>src/my b~.gleam</h2>\n",
              "<p>Lines: 0/1. Cover: <span class=\"low\">0.0%</span>.</p>\n",
              "<table class=\"source\">\n",
              source_header(),
              "<tbody>\n",
              "<tr class=\"missed\"><td class=\"number\">1</td><td class=\"number\">0</td><td></td></tr>\n",
              "</tbody>\n",
              "</table>\n",
              "</section>\n",
            ]),
          )
          |> or_fail_with("expected the combined document")
        },
      ),
      it("renders ignored, missed and escaped lines in a section", fn() {
        report.new([cart_file()])
        |> html.combined(
          sources: dict.from_list([#("src/app/cart.gleam", cart_source())]),
        )
        |> after_summary_table()
        |> should
        |> be_equal(
          string.concat([
            "<p>Excluded: 3 lines in 1 file</p>\n",
            cart_section(),
            "</body>\n",
            "</html>\n",
          ]),
        )
        |> or_fail_with("expected the cart section")
      }),
    ]),
    group("page_path", [
      it("keeps a plain source path", fn() {
        html.page_path("src/app/cart.gleam")
        |> should
        |> be_equal("files/src/app/cart.gleam.html")
        |> or_fail_with("expected files/src/app/cart.gleam.html")
      }),
      it("escapes other characters as UTF-8 bytes", fn() {
        html.page_path("src/My cart~\u{E9}\t1_2-3.gleam")
        |> should
        |> be_equal("files/src/My~20cart~7E~C3~A9~091_2-3.gleam.html")
        |> or_fail_with("expected the escaped page path")
      }),
      it("escapes empty, dot, dot-dot and .html folder parts", fn() {
        html.page_path("/abs/../x.html/./..")
        |> should
        |> be_equal("files/~/abs/~2E~2E/x~2Ehtml/~2E/~2E~2E.html")
        |> or_fail_with("expected the escaped parts")
      }),
    ]),
  ])
}
