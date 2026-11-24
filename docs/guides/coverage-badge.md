# Publish a coverage badge from your own CI

A coverage badge in your README tells every visitor how much of the code the tests run, and it keeps you honest when the number drops. Most badges come from an outside coverage service that wants your code and a token. You don't need one. Your own GitHub Actions workflow already measures the coverage. It can write one small JSON file to a `badges` branch, and [shields.io](https://shields.io/badges/endpoint-badge) draws the badge from that file. This guide sets that up, with the exact workflow that Dream Test uses for its own badge.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How the badge gets made](#how-the-badge-gets-made)
- [Which parts you need](#which-parts-you-need)
- [Step 1: Write the JSON summary](#step-1-write-the-json-summary)
- [Step 2: Read the total in the test job](#step-2-read-the-total-in-the-test-job)
- [Step 3: Publish the badge from a second job](#step-3-publish-the-badge-from-a-second-job)
- [Step 4: Add the badge to your README](#step-4-add-the-badge-to-your-readme)
- [The badge colour](#the-badge-colour)
- [When the badge doesn't work](#when-the-badge-doesnt-work)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Make your test run write a JSON summary of the coverage.
- Read the total and a colour from it in CI, on every push and pull request.
- Publish a badge file to a `badges` branch from a job that runs no project code.
- Show the badge in your README, with a link to the CI runs.

## Before you start

You need coverage in your test run. [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md) sets it up.

```sh
gleam add --dev dream_test
```

The setup works for a public GitHub repository with GitHub Actions. It uses only `git`, `jq` and `base64`, which every `ubuntu-latest` runner has, and no third-party action.

## How the badge gets made

- **The test job measures.** `gleam test` writes a JSON summary of the coverage.
- **The test job reads the total.** A shell step turns the total into a badge text, such as `80.0%`, and a colour.
- **A second job publishes.** It runs only on a push to `main`. It commits `coverage.json` to the `badges` branch. It runs no project code, so it's the only job with write access.
- **shields.io draws.** The README image asks shields.io for a badge, and shields.io reads `coverage.json` from the `badges` branch.

The `badges` branch shares no history with your code. It holds only `coverage.json`, and each changed total adds one commit.

## Which parts you need

| Your situation | Do | Why |
|:---|:---|:---|
| No workflow yet | Copy the parts of Steps 2 and 3 into `.github/workflows/ci.yml`, with your checkout, setup and test steps | The badge needs the test job and the publish job in one workflow. |
| A workflow with a test job already | Add the `outputs`, `id: tests` and the read step to your test job, and add the publish job | The publish job reads the test job by its id `test`. |
| A private repository | Don't use this setup | shields.io can't read `raw.githubusercontent.com` of a private repository without a token. |

## Step 1: Write the JSON summary

Set `coverage.json_path` in your test `main`. The badge step reads `total` and `minimum_percent` from this file:

### Coverage for the badge <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_badge.gleam#L20-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

The minimum is optional. It sets the badge colour (see [The badge colour](#the-badge-colour)). With `runner.exit_on_failure`, a total below the minimum makes `gleam test` end with exit status 1, so the test job fails. The workflow still reads the total and publishes it, in red. It also publishes when tests fail: the badge shows the coverage that the run measured.

If you use `runner.coverage_from_environment`, set `DREAM_TEST_COVERAGE: "1"` on the `gleam test` step. Without coverage, no JSON file is written: then the badge step fails when the tests passed, and writes no badge text when they failed, so nothing is published.

## Step 2: Read the total in the test job

These are the lines of Dream Test's own workflow, `.github/workflows/ci.yml`. The test job must have the id `test`, and declare two outputs for the publish job:

### The outputs of the test job <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L19-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
  test:
    name: Build & Test
    runs-on: ubuntu-latest
    outputs:
      coverage_message: ${{ steps.coverage_badge.outputs.message }}
      coverage_color: ${{ steps.coverage_badge.outputs.color }}
```

The step that runs the tests needs `id: tests`, because the read step checks its result. Dream Test runs its tests from a script. In your project, this step runs `gleam test`:

### The test step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L58-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
      - name: Check, build and test
        id: tests
        env:
          CI: "true"
        run: sh scripts/check.sh
```

The last step of the test job reads the JSON summary, and writes the badge text and colour to the job outputs:

### The read step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L67-L107"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
      - name: Read coverage for the badge
        # Runs on every event, so a pull request also shows that the JSON
        # summary is readable. Only the badge job below publishes. It also
        # runs when an earlier step failed: the badge shows the coverage
        # that the run measured, also when tests failed or the total is
        # below the minimum (then in red).
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
```

What it does:

- It runs on every event, so a pull request also shows that the JSON is readable. `!cancelled()` makes it run also when `gleam test` failed.
- It fails when the tests passed and the file is missing, or when the file has no executable lines. When `gleam test` failed and wrote no file, it writes no badge text and passes.
- The `jq` program applies [the colour rule](#the-badge-colour) to the exact line counts. The badge text is `total.percent` from the JSON, which is already rounded down, with one decimal: `80.0%`.

## Step 3: Publish the badge from a second job

The publish job reads the outputs of the test job and commits `coverage.json` to the `badges` branch:

### The publish job <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/.github/workflows/ci.yml#L109-L174"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
  coverage-badge:
    name: Publish coverage badge
    # Only a push to main in this repository publishes. Pull requests and
    # forks never do. The job publishes whenever the test run wrote the
    # coverage JSON and the read step produced a badge text, also when tests
    # failed or the total is below the minimum. A test run that wrote no
    # coverage JSON publishes nothing.
    if: ${{ !cancelled() && needs.test.outputs.coverage_message != '' && github.event_name == 'push' && github.ref == 'refs/heads/main' && github.repository == 'TrustBound/dream_test' }}
    needs: test
    runs-on: ubuntu-latest
    # This job runs no project code. It only writes one file to the
    # `badges` branch.
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

Change `TrustBound/dream_test` in the `if:` line to your repository, and `main` to your default branch if it has another name. What each part does:

| Part | Why |
|:---|:---|
| `if:` | Only a push to `main` in your repository publishes. Pull requests and forks skip the job. `!cancelled()` makes it run also when the test job failed, and `coverage_message != ''` skips it when no badge text was read. |
| `needs: test` | The job starts after the test job and reads its outputs. |
| `permissions: contents: write` | The push needs it. Only this job gets it, and this job runs no project code. |
| `concurrency` | Two quick pushes to `main` publish one after the other, not at the same time. |
| `git ls-remote` | Exit status `2` means there's no `badges` branch yet, so the step makes it as an orphan branch. |
| `git diff --cached --quiet` | No commit when the total didn't change. |
| `HEAD:refs/heads/badges` | The step pushes to `badges` only. It never touches another branch. |

## Step 4: Add the badge to your README

Replace `OWNER/REPO` with your repository:

```markdown
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/OWNER/REPO/badges/coverage.json)](https://github.com/OWNER/REPO/actions/workflows/ci.yml?query=branch%3Amain)
```

The link opens the runs of the workflow on `main`. Add `&style=flat-square`, or another shields.io style, to the image address to match your other badges.

Then push to `main`, and check it:

1. Open the `Publish coverage badge` job in the Actions tab. Its last line is `Coverage badge published: 80.0% (yellow)`, or `Coverage badge unchanged: 80.0%` when the total didn't change.
2. Run `git fetch origin badges`, then `git show origin/badges:coverage.json`. It prints the badge file.
3. Open `https://raw.githubusercontent.com/OWNER/REPO/badges/coverage.json` in a browser. It shows the same JSON.

## The badge colour

The colour follows the rule of the coloured coverage table (`coverage.color()`):

| Total | Colour |
|---|---|
| 100% | `green` |
| below `coverage.minimum_percent` | `red` |
| at the minimum or above, below 100% | `yellow` |
| no minimum: below 50% | `red` |
| no minimum: 50% or above, below 100% | `yellow` |

The comparison uses the exact line counts, like `coverage.check_minimum`.

## When the badge doesn't work

| Problem | Cause and fix |
|---|---|
| The badge shows an error in place of a percent | No push to `main` published the file yet. Push to `main` once. |
| The badge shows an old value | GitHub and shields.io keep a copy for a few minutes. Wait about five minutes. |
| The job is `skipped` | The `if:` doesn't match. Check the branch name and the repository name. In a fork, the job is skipped on purpose. To publish from a fork, set the fork's own name. |
| `Permission to OWNER/REPO.git denied to github-actions[bot]` (403) | The job has no write access. Keep `permissions: contents: write` on the job. If your organization blocks write access for workflows, an admin must allow it in Settings, Actions, General, Workflow permissions. |
| `protected branch hook declined` or a ruleset error | A branch protection rule or ruleset covers `badges`, often with a pattern such as `*` or `**`. Remove `badges` from the rule, or let GitHub Actions bypass it. |
| `Coverage badge failed: build/coverage/coverage.json does not exist.` | The test run didn't write the JSON. Set `coverage.json_path`, and turn coverage on in CI (`DREAM_TEST_COVERAGE` when you use `runner.coverage_from_environment`). |
| The badge doesn't turn red when the total falls below the minimum | The total below the minimum fails `gleam test`, and steps and jobs without a status function in their `if:` are skipped after a failure. Keep `!cancelled()` in the `if:` of the read step and of the publish job. |
| `the coverage JSON has no executable lines` | Coverage found no lines to measure. Check `coverage.source_directory` and your exclusions. |
| `failed to push some refs` (not a fast-forward) | Another run pushed to `badges` at the same time. Keep the `concurrency` group, then run the job again. |
| The badge never loads in a private repository | `raw.githubusercontent.com` needs a token for a private repository, and shields.io has none. This setup works only for a public repository. |

## Test your code

The read step is the part most likely to break, and you can run it on your machine before you push. Run your tests with coverage so the JSON summary exists, then run the `jq` program of the read step against `build/coverage/coverage.json`. It prints `green`, `yellow` or `red`. A file from a run with no executable lines makes `jq` fail with `the coverage JSON has no executable lines`, as CI would.

The JSON summary itself is tested in this repository: the [coverage guide](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md#step-7-write-files-for-other-tools) shows a real one, and its test compares it with a real coverage run.

## Common pitfalls

**A publish job without `!cancelled()`.** *Symptom:* the badge stays green while CI is red. *Fix:* keep `!cancelled()` in the `if:` of the read step and of the publish job, so a failed test run still publishes its real total.

**Write access for the test job.** *Symptom:* code from a pull request could push to your repository. *Fix:* give `contents: write` only to the publish job, which runs no project code.

**A badge branch under branch protection.** *Symptom:* `protected branch hook declined`. *Fix:* leave `badges` out of your rules.

**No `id: test` on the test job.** *Symptom:* the publish job can't read `needs.test.outputs`. *Fix:* name the job `test`, or change `needs:` and `needs.test` to its id.

## Where to go next

- [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md): the minimum, the exclusions and the JSON summary.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): the exit status that fails the test job.
- [shields.io endpoint badges](https://shields.io/badges/endpoint-badge): the format of `coverage.json`, and the badge styles.
