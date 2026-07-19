---
name: release
description: Create a GitHub release. Commits and pushes outstanding changes first, then drafts release notes for confirmation. Deployment is only triggered if the project has a release-triggered workflow.
disable-model-invocation: true
---

# Release

## Goal

Create a GitHub release. Ensures all local changes are committed and pushed before creating the release.

## Workflow

1. **Fetch release tags from the remote**:

   ```
   git fetch --tags
   ```

   Required because `gh release create` creates tags on the remote at commits that are usually already in local history, and git's default tag-follow policy only downloads tags pointing at newly fetched commits — so without an explicit fetch, the previous release tag won't exist locally and subsequent `<previous_tag>..HEAD` ranges fail with "ambiguous argument".

2. **Commit and push outstanding changes**:

   Run the `/commit` skill to commit and push any outstanding changes. If there are no changes, continue to the next step.

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
