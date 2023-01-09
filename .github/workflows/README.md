# build.yaml

## flutter-prep

This job handles caching the flutter candidate, so that we don't need to keep downloading it and setting it up for each job.

### Clearing the cache

To clear the Github Actions cache for a specific flutter candidate:

- Navigate to  [Devtool's Actions Caches](https://github.com/flutter/devtools/actions/caches)
- Filter for the candidate you would like to clear
- Delete all of the cache entries for your candidate
  - There should be a Linux and a MacOS entry for each candidate
