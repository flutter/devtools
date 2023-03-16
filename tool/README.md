## How to release the next version of DevTools

### Configure/Refresh environment

Make sure:

1. Your Dart SDK is configured:

   a. You have a local checkout of the Dart SDK
      - (for getting started instructions, see [sdk/CONTRIBUTING.md](https://github.com/dart-lang/sdk/blob/main/CONTRIBUTING.md)).

   b. Ensure your `.bashrc` sets `$LOCAL_DART_SDK`

       ```shell
       DART_SDK_REPO_DIR=<Path to cloned dart sdk>
       export LOCAL_DART_SDK=$DART_SDK_REPO_DIR/sdk
       ```

   c. The local checkout is at `main` branch: `git rebase-update`

2. Your Flutter version is equal to latest candidate release branch:
    - Run `./tool/update_flutter_sdk.sh --local` from the main devtools directory.
3. You have goma [configured](http://go/ma-mac-setup).

### Prepare the release

#### Update the DevTools version number

- Make sure your working branch is clean
- Run the `tool/release_helper.sh` script with `minor` or `major`.
   `./tool/release_helper.sh [minor|major]`
- This creates 2 branches for you:
    - Release Branch
    - Next Branch
- The following steps will guide you through how these branches will be prepared and merged.
- **For your convenience, the `tool/release_helper.sh` script exports the following two variables to the terminal it is run in:**
  - `$DEVTOOLS_RELEASE_BRANCH`
  - `$DEVTOOLS_NEXT_BRANCH`

#### Verify the version changes for `$DEVTOOLS_RELEASE_BRANCH`

Verify release_helper.sh script:
- updated the pubspecs under packages/
- updated all references to those packages
- updated the version constant in `packages/devtools_app/lib/devtools.dart`

These packages always have their version numbers updated in lock, so we don't have to worry about versioning.

#### Manually review the CHANGELOG.md in `$DEVTOOLS_RELEASE_BRANCH`

Review/update `CHANGELOG.md`:

1. Verify all changes are here:

    * Open [commits](https://github.com/flutter/devtools/commits/master)
    * Search for last PR, commented for previous version in CHANGELOG
    * Make sure all PRs since the found one are included.
      You may want to re-run `dart tool/bin/repo_tool.dart generate-changelog  --since-tag=<tag like v1.5.2>` with passed parameter
      for the tag.

2. Verify the version for the CHANGELOG entry was correctly generated.
3. Verify each item is a complete sentence, written as though it was an order, and there is no syntax errors.
4. Create draft PR for the branch and add the item for it to the top.

### Test the `$DEVTOOLS_RELEASE_BRANCH`

- Checkout the `$DEVTOOLS_RELEASE_BRANCH`,
- Build the DevTools binary and run it from your local Dart SDK.
   - From the main devtools/ directory.
   ```shell
   dart ./tool/build_e2e.dart
   ```

- Launch DevTools and verify that everything generally works.
   - open the page in a browser (http://localhost:53432)
   - `flutter run` an application
   - connect to the running app from DevTools
   - verify:
      - pages generally work
      - there are no exceptions in the chrome devtools log
   - If you find any release blocking issues:
      - fix them before releasing.
      - Then grab the latest commit hash that includes
         - the release prep commit
         - the bug fixes,
      - use this commit hash for the following steps.

- Once the build is in good shape,
   - revert any local changes.
      ```shell
      git checkout . && \
      git clean -f -d;
      ```

#### Push the `$DEVTOOLS_RELEASE_BRANCH`

> Ensure you are still on the `$DEVTOOLS_RELEASE_BRANCH`

```shell
git push -u origin $DEVTOOLS_RELEASE_BRANCH
```

From the git GUI tool or from github.com directly:
1. Create a PR.
2. Add the entry about the created PR to the CHANGELOG.md manually, and push to the PR.
3. Receive an LGTM, squash and commit.


### Tag the release
- Checkout the commit from which you want to release DevTools
   - This is likely the commit for the PR you just landed
   - You can run `git log -v` to see the commits.
- Run the `tag_version.sh` script
   - this creates a tag on the `flutter/devtools` repo for this release.
   - This script will automatically determine the version from `packages/devtools/pubspec.yaml` so there is no need to manually enter the version.

   ```shell
   tool/tag_version.sh;
   ```

### Verify and Submit the release notes

See the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/release_notes/release_notes/README.md)
for details on where to add DevTools release notes to Flutter website and how to test them.

- Follow the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/framework/release_notes/README.md)
to add release notes to Flutter website
  - On the `$DEVTOOLS_RELEASE_BRANCH` copy the release notes from [NEXT_RELEASE_NOTES.md](../packages/devtools_app/release_notes/NEXT_RELEASE_NOTES.md)
    - These are the release notes you will submit through the flutter/website PR.
  - make sure to also follow the instructions to test them.


### Upload the DevTools binary to CIPD
- Use the update.sh script to build and upload the DevTools binary to CIPD:
   ```shell
   TARGET_COMMIT_HASH=<Commit hash for the version bump commit in DevTools>
   ```

   ```shell
   cd $LOCAL_DART_SDK && \
   git rebase-update && \
   third_party/devtools/update.sh $TARGET_COMMIT_HASH [optional --no-update-flutter];
   ```
For cherry pick releases that need to be built from a specific version of Flutter,
checkout the Flutter version on your local flutter repo (the Flutter SDK that
`which flutter` points to). Then when you run the `update.sh` command, include the
`--no-update-flutter` flag:

   ```shell
   third_party/devtools/update.sh $TARGET_COMMIT_HASH --no-update-flutter
   ```

### Update the DevTools hash in the Dart SDK

- Create new branch for your changes:
   ```shell
   cd $LOCAL_DART_SDK && \
   git new-branch dt-release;
   ```

- Update the `devtools_rev` entry in the Dart SDK [DEPS file](https://github.com/dart-lang/sdk/blob/master/DEPS)
   - set the `devtools_rev` entry to the `TARGET_COMMIT_HASH`.
   - See this [example CL](https://dart-review.googlesource.com/c/sdk/+/215520) for reference.


- Build the dart sdk locally

   ```shell
   cd $LOCAL_DART_SDK && \
   gclient sync -D && \
   ./tools/build.py -mrelease -ax64 create_sdk;
   ```

- Verify that running `dart devtools` launches the version of DevTools you just released.
   - for OSX
      ```shell
      xcodebuild/ReleaseX64/dart-sdk/bin/dart devtools
      ```
   - For non-OSX
      ```shell
      out/ReleaseX64/dart-sdk/bin/dart devtools
      ```

- If the version of DevTools you just published to CIPD loads properly

   > You may need to hard reload and clear your browser cache in order to see the changes.

   - push up the SDK CL for review.
      ```shell
      git add . && \
      git commit -m "Bump DevTools DEP to $NEW_DEVTOOLS_VERSION" && \
      git cl upload -s;
      ```

### Publish package:devtools_shared on pub

`package:devtools_shared` is the only DevTools package that is published on pub.

- From the `devtools/packages/devtools_shared` directory, run:
   ```shell
   flutter pub publish
   ```

### Push the DEVTOOLS_NEXT_BRANCH
```shell
git pull upstream master
git checkout $DEVTOOLS_NEXT_BRANCH
git push -u origin $DEVTOOLS_NEXT_BRANCH
```

From the git GUI tool or from github.com directly:
1. Create a PR.
2. Receive an LGTM, squash and commit.

## Debug Logs

Debug logs found in `Settings > Copy Logs` are saved such that they can be read by (lnav)[https://lnav.org/]

### Configuring `lnav` for linux and MacOS
> For Windows, you will need find a different program to parse and read these logs.

- Follow the installation instructions found at https://lnav.org/downloads
- After installation create a symbolic link to the `tool/devtools_lnav.json` file, inside the `lnav` formats:
   ```sh
      ln -s ${DEVTOOLS}/tool/devtools_lnav.json ~/.lnav/formats/installed/`
   ```
- Your `lnav` installation will now be able to format logs created by Dart DevTools.

### Reading logs using `lnav`
- Save your Dart DevTools [Debug Logs](#debug-logs) to a file.
  ```sh
  DEBUG_LOGS=/path/to/your/logs # Let DEBUG_LOGS represent the path to your log file.
  ```
- Open the logs
  ```sh
  lnav $DEBUG_LOGS
  ```
- You should now be navigating the nicely formatted Dart Devtools Logs inside `lnav`

### `lnav` tips

For a quick tutorial on how to navigate logs using `lnav`
you can give [ their tutorial ](https://lnav.org/tutorials) a try.
