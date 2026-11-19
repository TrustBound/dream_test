## Coverage badge on GitHub

This chapter shows how to put a live coverage badge in your README. Your own GitHub Actions workflow measures the coverage, then writes one small JSON file to a `badges` branch. [shields.io](https://shields.io/badges/endpoint-badge) reads that file and draws the badge. No outside coverage service gets your code or a token.

Dream Test uses the same setup for its own badge.

### Mental model

- **The test job measures.** `gleam test` writes a JSON summary of the coverage.
- **The test job reads the total.** A shell step turns the total into a badge text (`80.0%`) and a colour.
- **A second job publishes.** It runs only on a push to `main`. It publishes whenever `gleam test` measured the coverage and wrote the JSON, also when tests failed or the total is below the minimum. It commits `coverage.json` to the `badges` branch. It runs no project code, so it is the only job with write access.
- **shields.io draws.** The README image asks shields.io for a badge. shields.io reads `coverage.json` from the `badges` branch.

The `badges` branch has no shared history with your code. It holds only `coverage.json`, and each changed total adds one commit.

### 1. Write the JSON summary

Set `coverage.json_path` in your test `main`. The badge step reads `total` and `minimum_percent` from this file.

#### Coverage for the badge <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_badge.gleam#L20-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.json_path("build/coverage/coverage.json")
  |> coverage.minimum_percent(80.0)
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The minimum is optional. It sets the badge colour (see below). With `runner.exit_on_failure`, a total below the minimum makes `gleam test` end with exit status 1, so the `test` job fails. The workflow below still reads the total and publishes it, in red. It also publishes when tests fail: the badge shows the coverage that the run measured. If you use `runner.coverage_from_environment`, set `DREAM_TEST_COVERAGE: "1"` on the `gleam test` step. Without coverage, no JSON file is written and the badge step fails.

### 2. Add the workflow

Save this file as `.github/workflows/coverage.yml`, or copy the two parts into your existing workflow:

- the `outputs` and the last step of the `test` job
- `id: tests` on your `gleam test` step, because the last step reads its result
- the whole `coverage-badge` job

Replace `OWNER/REPO` with your repository. Change `main` if your default branch has a different name.

```yaml
name: Coverage

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    outputs:
      coverage_message: ${{ steps.coverage_badge.outputs.message }}
      coverage_color: ${{ steps.coverage_badge.outputs.color }}
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          otp-version: "28"
          gleam-version: "1.19.2"
          rebar3-version: "3"

      - name: Run tests
        id: tests
        run: gleam test

      - name: Read coverage for the badge
        id: coverage_badge
        if: ${{ !cancelled() }}
        env:
          COVERAGE_JSON: build/coverage/coverage.json
          TESTS_OUTCOME: ${{ steps.tests.outcome }}
        run: |
          set -euo pipefail
          if [ ! -f "$COVERAGE_JSON" ]; then
            if [ "$TESTS_OUTCOME" != "success" ]; then
              # The test run stopped before it wrote the JSON, for example
              # at a compile error. The failed test step shows why.
              echo "No coverage badge: the test run wrote no $COVERAGE_JSON."
              exit 0
            fi
            echo "Coverage badge failed: $COVERAGE_JSON does not exist."
            echo "Fix: set coverage.json_path(\"$COVERAGE_JSON\") in the test main."
            exit 1
          fi
          # The colour rule of the coverage table: green at 100%, red below
          # the minimum (50% when no minimum is set), yellow between them.
          color=$(jq -r '
            .total as $total
            | (.minimum_percent // 50) as $minimum
            | if $total.lines_total == 0 then
                error("the coverage JSON has no executable lines")
              elif $total.lines_hit == $total.lines_total then "green"
              elif $total.lines_hit * 100 < $minimum * $total.lines_total then "red"
              else "yellow"
              end
          ' "$COVERAGE_JSON")
          percent=$(jq -r '.total.percent' "$COVERAGE_JSON")
          message=$(printf '%.1f%%' "$percent")
          echo "Coverage badge: $message ($color)"
          echo "message=$message" >> "$GITHUB_OUTPUT"
          echo "color=$color" >> "$GITHUB_OUTPUT"

  coverage-badge:
    if: ${{ !cancelled() && needs.test.outputs.coverage_message != '' && github.event_name == 'push' && github.ref == 'refs/heads/main' && github.repository == 'OWNER/REPO' }}
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: write
    concurrency:
      group: coverage-badge
      cancel-in-progress: false
    steps:
      - name: Commit the badge to the badges branch
        env:
          MESSAGE: ${{ needs.test.outputs.coverage_message }}
          COLOR: ${{ needs.test.outputs.coverage_color }}
          GITHUB_TOKEN: ${{ github.token }}
          REMOTE_URL: https://github.com/${{ github.repository }}.git
        run: |
          set -euo pipefail
          workdir=$(mktemp -d)
          cd "$workdir"
          git init -q
          git remote add origin "$REMOTE_URL"
          auth=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')
          git config http.https://github.com/.extraheader "AUTHORIZATION: basic $auth"
          git config user.name "github-actions[bot]"
          git config user.email "41898299+github-actions[bot]@users.noreply.github.com"

          # Exit status 2 means the branch does not exist yet. Any other
          # failure (network, access) stops the job.
          set +e
          git ls-remote --exit-code --heads origin refs/heads/badges > /dev/null
          status=$?
          set -e
          case "$status" in
            0)
              git fetch -q --depth 1 origin refs/heads/badges
              git checkout -q -B badges FETCH_HEAD
              ;;
            2)
              git checkout -q --orphan badges
              ;;
            *)
              echo "Coverage badge failed: git ls-remote exited with $status."
              exit "$status"
              ;;
          esac

          jq -n -c --arg message "$MESSAGE" --arg color "$COLOR" \
            '{schemaVersion: 1, label: "coverage", message: $message, color: $color}' \
            > coverage.json
          git add coverage.json
          if git diff --cached --quiet; then
            echo "Coverage badge unchanged: $MESSAGE"
            exit 0
          fi
          git commit -q -m "Coverage badge: $MESSAGE"
          git push -q origin HEAD:refs/heads/badges
          echo "Coverage badge published: $MESSAGE ($COLOR)"
```

What each part does:

| Part | Why |
|---|---|
| `id: tests` | The read step gets the result of `gleam test` from it. |
| `Read coverage for the badge` | Runs on every event, so a pull request also shows that the JSON is readable. `!cancelled()` makes it run also when `gleam test` failed. It fails when the tests passed and the file is missing, or when the file has no executable lines. When `gleam test` failed and wrote no file, it writes no badge text. |
| `if:` on `coverage-badge` | Only a push to `main` in your repository publishes. Pull requests and forks skip the job. `!cancelled()` makes it run also when the `test` job failed, so it publishes whenever coverage was measured, also when tests failed. `coverage_message != ''` skips it when no badge text was read. |
| `needs: test` | The job starts after the `test` job and reads its badge text. |
| `permissions: contents: write` | The push needs it. Only this job gets it, and this job runs no project code. |
| `concurrency` | Two quick pushes to `main` publish one after the other, not at the same time. |
| `git ls-remote` | Exit status `2` means there is no `badges` branch yet, so the step makes it as an orphan branch. |
| `git diff --cached --quiet` | No commit when the total did not change. |
| `HEAD:refs/heads/badges` | The step pushes to `badges` only. It never touches another branch. |

The step uses only `git`, `jq` and `base64`, which every `ubuntu-latest` runner has. It needs no third-party action.

### 3. The badge colour

The colour follows the rule of the coloured coverage table (`coverage.color()`):

| Total | Colour |
|---|---|
| 100% | `green` |
| below `coverage.minimum_percent` | `red` |
| at the minimum or above, below 100% | `yellow` |
| no minimum: below 50% | `red` |
| no minimum: 50% or above, below 100% | `yellow` |

The comparison uses the exact line counts, like `coverage.check_minimum`. The badge text is the rounded-down `total.percent` from the JSON, with one decimal: `80.0%`.

### 4. Add the badge to your README

Replace `OWNER/REPO` again:

```text
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/OWNER/REPO/badges/coverage.json)](https://github.com/OWNER/REPO/actions/workflows/coverage.yml?query=branch%3Amain)
```

The link opens the runs of the workflow on `main`. Add `&style=flat-square` (or another shields.io style) to the image address to match your other badges.

### 5. Make sure it works

1. Push to `main`.
2. Open the `coverage-badge` job in the Actions tab. The last line is `Coverage badge published: 80.0% (yellow)`, or `Coverage badge unchanged: 80.0%` when the total did not change.
3. Read the file from the branch:

   ```sh
   git fetch origin badges
   git show origin/badges:coverage.json
   ```

4. Open `https://raw.githubusercontent.com/OWNER/REPO/badges/coverage.json` in a browser. It shows the same JSON.

### Troubleshooting

| Problem | Cause and fix |
|---|---|
| The badge shows an error in place of a percent | No push to `main` published the file yet. Push to `main` once. |
| The badge shows an old value | GitHub and shields.io keep a copy for a few minutes. Wait about five minutes. |
| The job is `skipped` | The `if:` does not match. Check the branch name and the `OWNER/REPO` value. In a fork, the job is skipped on purpose. To publish from a fork, set the fork's own name. |
| `Permission to OWNER/REPO.git denied to github-actions[bot]` (403) | The job has no write access. Keep `permissions: contents: write` on the job. If your organization blocks write access for workflows, an admin must allow it in Settings, Actions, General, Workflow permissions. |
| `protected branch hook declined` or a ruleset error | A branch protection rule or ruleset covers `badges`, often with a pattern such as `*` or `**`. Remove `badges` from the rule, or let GitHub Actions bypass it. |
| `Coverage badge failed: build/coverage/coverage.json does not exist.` | The test run did not write the JSON. Set `coverage.json_path`, and turn coverage on in CI (`DREAM_TEST_COVERAGE` when you use `runner.coverage_from_environment`). |
| The badge does not turn red when the total falls below the minimum | The total below the minimum fails `gleam test`. Steps and jobs without a status function in their `if:` are skipped after a failure. Keep `!cancelled()` in the `if:` of the read step and of the `coverage-badge` job. |
| `the coverage JSON has no executable lines` | Coverage found no lines to measure. Check `coverage.source_directory` and your exclusions. |
| `failed to push some refs` (not a fast-forward) | Another run pushed to `badges` at the same time. Keep the `concurrency` group, then run the job again. |
| The badge never loads in a private repository | `raw.githubusercontent.com` needs a token for a private repository, and shields.io has none. This setup works only for a public repository. |

### What's Next?

- Go back to [Utilities](11-utilities.md)
- Go back to [Documentation README](README.md)
- Read the Coverage section of the [main README](../README.md#coverage)
- Continue to [Upgrading to 3.0.0](13-upgrading-to-3.md)
