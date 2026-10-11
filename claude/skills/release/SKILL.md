---
name: release
description: Create a GitHub release from the default branch. In a trunk project, commits and pushes outstanding changes first; in a feature-branch project, stops if there are any. Then drafts release notes for confirmation. Deployment is only triggered if the project has a release-triggered workflow.
disable-model-invocation: true
context: fork
---

# Release

## Goal

Create a GitHub release. Under trunk, commits and pushes all local changes before creating the release; under feature branches, requires a clean default branch holding nothing `origin` lacks.

## Workflow

0. **Run from the main checkout, never a linked worktree.** If `git rev-parse --path-format=absolute --git-dir --git-common-dir` prints two different paths, stop before doing anything: this skill runs as a fork, and publishing from a linked worktree (`~/.claude/skills/publish.md` § *Integrate from a linked worktree*) has to move the session out of the tree, which a fork cannot do. Tell the user to land the branch first — `/ship` where the project opts in to worktree integration, or by hand — and then run `/release` from a session in the main checkout.

1. **Fetch release tags from the remote**:

   ```
   git fetch --tags
   ```

   Required because `gh release create` creates tags on the remote at commits that are usually already in local history, and git's default tag-follow policy only downloads tags pointing at newly fetched commits — so without an explicit fetch, the previous release tag won't exist locally and subsequent `<previous_tag>..HEAD` ranges fail with "ambiguous argument".

2. **Commit and push outstanding changes**:

   Check before committing anything, so a release never leaves work committed somewhere it did not mean to:
   - **On the default branch.** Name `<default>` as `~/.claude/skills/publish.md` § *Names used below* does; if `git branch --show-current` prints anything else, stop and say a release is cut from the default branch.
   - **By the branch model** (`publish.md` § *Branch model*). Under **feature branches** the default branch takes no commits from here: if there are outstanding changes (`git status --porcelain --untracked-files=all` prints anything) or commits `origin` lacks (`git rev-list --count origin/<default>..HEAD` above zero), stop and name them — `git status --porcelain --untracked-files=all` for the uncommitted ones, `git log --oneline origin/<default>..HEAD` for the commits — they belong on a branch and a pull request, which is the user's to arrange; with neither, continue to the next step. Under **trunk**, go on below.

   Then, under trunk: if there are outstanding changes, commit them by following the `/commit` skill; it never pushes. Then push whatever the default branch holds that `origin` lacks (`git rev-list --count origin/<default>..HEAD` above zero), per `publish.md` § *Push the default branch*. If there is nothing to commit or push, continue to the next step.

3. **Detect previous release**:

   ```
   gh release list --limit 1 --json tagName --jq '.[0].tagName'
   ```

4. **Determine next release number**:

   Extract the number from the previous tag and add 1 to get the next release number (e.g., previous tag `r138` → next release `r139`).

   If no previous release, use 0 as the starting number.

5. **List commits since the previous release**:

   ```
   git log --format="%h %s" <previous_tag>..HEAD
   ```

   If no previous release, use the full commit history.

6. **Read the actual diffs** for context when commit messages are unclear:

   ```
   git diff <previous_tag>..HEAD --stat
   ```

   And selectively read individual diffs for commits whose messages don't clearly convey the user-facing impact.

7. **Categorize and summarize** each meaningful change into a user-facing bullet point:

   - Focus on **what users can now do** or **what improved**.

   - Ignore purely internal changes (refactoring, linting, CI, dependency updates) unless they affect performance or reliability in a way users would notice.

   - Group related commits into a single bullet when they contribute to the same feature or fix.

   - Use plain, non-technical language.

8. **Present the draft** to the user and ask for confirmation using AskUserQuestion. Show the release tag, title, and notes.

9. **Create the GitHub release** (only after user confirms):

   ```
   gh release create r<N> --title "Release <N>" --notes "<notes>"
   ```

10. **Report deployment status**:

    Do NOT assume the release triggers a deployment — many projects have no release-triggered automation. Check `.github/workflows/` for a workflow triggered by `release` (or a push of `r*` tags). If one exists, tell the user deployment has been triggered by the release. If not, tell the user the release does not deploy anything, and point out how the project is deployed instead if it's apparent (e.g., `fly.toml` -> `fly deploy`). Only run a deployment if the user asks for it.

## Writing Style

- Use simple, clear language a non-technical user would understand.

- Describe capabilities and outcomes, not implementation details.

- Avoid technical jargon (no "refactor", "API", "migration", "endpoint").

- Each bullet should be one concise sentence.

- Skip changes that have no user-visible impact.

## Examples

**Good bullets:**

- New page to manage users' email addresses.

- Improved search speed when looking for companies.

- Added support for special characters in company names.

**Bad bullets (too technical):**

- Refactored user email management to a separate service.

- Added database index on organization_number to improve query performance.

- Updated dependencies to the latest versions.
