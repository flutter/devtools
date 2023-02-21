# build.yaml

## flutter-prep

This job handles caching the flutter candidate, so that we don't need to keep downloading it and setting it up for each job.

### Clearing the cache

To clear the Github Actions cache for a specific flutter candidate:

- Navigate to  [Devtool's Actions Caches](https://github.com/flutter/devtools/actions/caches)
- Filter for the candidate you would like to clear
- Delete all of the cache entries for your candidate
  - There should be a Linux and a MacOS entry for each candidate

# daily-dev-bump.yaml

The Daily Dev Bump workflow is meant to facilitate `-dev.*` version bumps, on a daily cadence.

Using a cron trigger, this workflow will:
- perform a dev version bump
- create a PR with an `autosubmit` label

- The PR will then be automatically approved and merged by the processes from the [ Flutter Cocoon repo ](https://github.com/flutter/cocoon),
  - The Flutter auto-submit bot automatically merges the PR.

## DartDevtoolWorkflowBot
In order to allow the automatic approval and submission of the version bump PRs,
[DartDevtoolWorkflowBot](https://github.com/DartDevtoolWorkflowBot) was created.

DartDevtoolWorkflowBot is a Github account that is used to author the version bump PRs in `daily-dev-bump.yaml`. It has special permissions so that when the Cocoon bots see a PR authored by DartDevtoolWorkflowBot, they can be automatically approved.

### DartDevtoolWorkflowBot Token Cycling

DartDevtoolWorkflowBot's Personal Access Token must be cycled every 90 days.
The instructions to rotate the token can be found in the email for the Dart DevTool Workflow Token rotation.

## Manually Performing a Dev Version Bump

To manually trigger a Dev Version Bump:
- Navigate to the [Action entry for Dev Bumps](https://github.com/flutter/devtools/actions/workflows/daily-dev-bump.yaml)
- Select `Run workflow`
- Run the workflow from `master`
