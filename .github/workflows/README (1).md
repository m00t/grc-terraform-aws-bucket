# Gate

Gate runs the policies on every pull request and blocks the ones that break a control.

1. Installed Conftest at a pinned version.
2. Runs the three policy namespaces against `plan.json`, writse results to `evidence/conftest-results.json`, and fails the job on any policy failure.
3. Uploads `evidence/` as an artifact with `if: always()` so it is saved on failure too.

## Two-PR demonstration

1. **Green PR.** Open a pull request with your compliant `plan.json`. The gate runs, passes, the PR is mergeable.
2. **Red PR.** Open a pull request where the plan breaks a control (regenerate `plan.json` from a workspace with encryption removed, or hand-edit one flag to false). The gate runs, fails, and with branch protection on, the merge is blocked.

Turn on branch protection (Settings, Branches) and require the `grc-gate` check, so the red PR cannot merge.

- A PR triggers the workflow and it appears in the Actions tab.
- The compliant PR ends green. The violating PR ends red and is blocked.
- An evidence artifact is attached to both runs.

