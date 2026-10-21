# 0010. Delivery flow: a branch first, a draft always, wait for CI

- Status: Accepted
- Date: 2026-10-21

## Context

An agent that finishes a change readily does three things badly: it edits on whichever branch it
happens to be on; it pushes and announces success, because from its side the push succeeded; it
opens a "ready" pull request before any build has run. These are not reasoning errors but gaps
in the instructions: nothing says where a change should live, that a push is not the end, or
what "all green" refers to.

Here, CI is long (build and tests on macOS, `.pkg` construction) and the repository is about to
become public: a red build pushed to `main` is visible.

## Decision

1. **A branch before the first edit.** Never commit on `main`; the naming convention is
   `<type>/<short-slug>` (AGENTS.md B8).
2. **A push opens a draft pull request**, always, even for a change judged finished.
3. **"Ready" is earned**: CI green on the head commit, `make check` green, review threads
   resolved, no conflict, template followed.
4. **The agent waits for the build**, then promotes or fixes. The wait is bounded (20 minutes);
   past that, it hands back the status of the checks as it stands instead of waiting forever or
   announcing a success.
5. **AGENTS.md B8 is the delivery contract**: forge, git model, branches, tags, versions, merge
   (squash), required checks (`build`, `package (.pkg)`, `guardrails`).
6. **`/ship`** runs the flow end to end; `/pr` writes the description from the template
   `.github/pull_request_template.md`.

## Consequences

- Work in progress is visible on GitHub from the first push, and the agent that broke a build
  fixes it while it still has the context.
- The delivery rules are written down once, for agents and humans alike.
- The flow needs `gh` and a GitHub repository: until the repository exists, `/ship` stops and
  says so.
- Waiting occupies the session; the budget is bounded and adjustable in B8.
- A project that wanted "ready on open" would have to override A14.
- No branch protection or required approval while the project has a single maintainer: to
  configure on GitHub (required CI, no force-push) at publication.

## Alternatives considered

- **Always open as ready**: spends reviewers' attention on changes that do not build.
- **Guess everything from the remote and the CI config**: the forge can be guessed, not the
  names of the required checks nor the merge strategy.
- **A hook that refuses a push with no PR**: the push and the PR are two calls; the problem is
  omission, not permission.
