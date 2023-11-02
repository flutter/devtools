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
    - Run `devtools_tool update-flutter-sdk --local`
3. You have goma [configured](http://go/ma-mac-setup).

### Prepare the release

#### Create a release PR

> If you need to install the [Github CLI](https://cli.github.com/manual/installation) you can run: `brew install gh`

- Ensure that you have access to `devtools_tool` by adding the `tool/bin` folder to your `PATH` environment variable
  - **MacOS Users**
    - add the following to your `~/.bashrc` file.
    - `export PATH=$PATH:<DEVTOOLS_DIR>/tool/bin`
      > [!NOTE]  
      > Replace `<DEVTOOLS_DIR>` with the local path to your DevTools
      > repo path.
  - **Windows Users**
    - Open "Edit environment variables for your account" from Control Panel
    - Locate the `Path` variable and click **Edit**
    - Click the **New** button and paste in `<DEVTOOLS_DIR>/tool/bin`
      > [!NOTE]  
      > Replace `<DEVTOOLS_DIR>` with the local path to your DevTools
      > repo path.

- Run: `devtools_tool release-helper`
- This will create a PR for you using the tip of master.
- The branch for that PR will be checked out locally for you.
- It will also update your local version of flutter to the Latest flutter candidate
    - This is to facilitate testing in the next steps

#### Verify the version changes for the Release PR

Verify the code on the release PR:
- updated the `devtools_app` and `devtools_test` pubspec versions
- updated all references to those packages in other `pubspec.yaml` files
- updated the version constant in `packages/devtools_app/lib/devtools.dart`

These packages always have their version numbers updated in lock, so we don't have to worry about versioning.

### Test the release PR

- Build DevTools in release mode and serve it from a locally running DevTools server instance:
   ```shell
   devtools_tool serve
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

#### Submit the Release PR

Receive an LGTM for the PR, squash and commit.

### Tag the release
- Checkout the commit from which you want to release DevTools
   - This is likely the commit, on `master`, for the PR you just landed
   - You can run `git log -v` to see the commits.
- Run the `tag_version.sh` script
   - this creates a tag on the `flutter/devtools` repo for this release.
   - This script will automatically determine the version from `packages/devtools/pubspec.yaml` so there is no need to manually enter the version.

   ```shell
   tool/tag_version.sh;
   ```

### Wait for the binary to be uploaded CIPD

On each DevTools commit, DevTools is built and uploaded to CIPD. You can check the
status of the builds on this [dashboard](https://ci.chromium.org/ui/p/dart-internal/builders/flutter/devtools). Within minutes, a build should be uploaded for the commit you just merged and tagged.

> [!NOTE]  
> If the CIPD build times out, instructions for re-triggering can be found at [go/dart-engprod/release.md](go/dart-engprod/release.md)

### Update the DevTools hash in the Dart SDK

Run the tool script with the commit hash you just merged and tagged:
```shell
devtools_tool update-sdk-deps -c <commit-hash>
```

This automatically creates a Gerrit CL with the DEPS update for DevTools.
Quickly test the build and then add a reviewer.

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

- If the version of DevTools you just published to CIPD does not load properly, 
you may need to hard reload and clear your browser cache.

- Add a reviewer and submit once approved.

### Publish DevTools pub packages

If `package:devtools_app_shared`, `package:devtools_extensions`, or `package:devtools_shared`
have unreleased changes, publish these packages to pub.

- From the respective `devtools/packages/devtools_*` directories, run:
   ```shell
   flutter pub publish
   ```

### Update to the next version
-  `gh workflow run daily-dev-bump.yaml -f updateType=minor+dev`
   -  This will kick off a workflow that will automatically create a PR with a `minor` + `dev` version bump
   -  That PR should then be auto submitted
-  See https://github.com/flutter/devtools/actions/workflows/daily-dev-bump.yaml
   -  To see the workflow run
-  Go to https://github.com/flutter/devtools/pulls to see the pull request that ends up being created
-  You should make sure that the release PR goes through without issue.

### Verify and Submit the release notes

1. Follow the instructions outlined in the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/release_notes/README.md)
to add DevTools release notes to Flutter website and test them in DevTools.
2. Once release notes are submitted to the Flutter website, send an announcement to g/flutter-internal-announce with a link to the new release notes.
