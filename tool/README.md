## How to release the next version of DevTools

### Configure/Refresh environment

Make sure:
1. You have a local checkout of the Dart SDK
   - (for getting started instructions, see [sdk/CONTRIBUTING.md](https://github.com/dart-lang/sdk/blob/main/CONTRIBUTING.md)).
2. Ensure your `.bashrc` sets `$LOCAL_DART_SDK`

   ```shell
   DART_SDK_REPO_DIR=<Path to cloned dart sdk>
   export LOCAL_DART_SDK=$DART_SDK_REPO_DIR/sdk
   ```
3. The local checkout is at `main` branch:
   - `git rebase-update`.
4. Your Flutter version is equal to latest candidate release branch:
    - Run `./tool/update_flutter_sdk.sh --local` from the main devtools directory.
5. You have goma [configured](http://go/ma-mac-setup).

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

#### Verify the version changes
> For both the `$DEVTOOLS_RELEASE_BRANCH` and the `$DEVTOOLS_NEXT_BRANCH` branches

Verify the version changes:
- that release_helper.sh script updated the pubspecs under packages/
- updated all references to those packages.
- make sure that the version constant in `packages/devtools_app/lib/devtools.dart` was updated

These packages always have their version numbers updated in lock, so we don't have to worry about versioning.

#### Manually review the CHANGELOG.md
> For both the `$DEVTOOLS_RELEASE_BRANCH` and the `$DEVTOOLS_NEXT_BRANCH` branches

* Verify
   * that the version for the CHANGELOG entry was correctly generated
   * that the entries don't have any syntax errors.

### Test the CLEAN_BRANCH 
> You only need to do this on the `$DEVTOOLS_RELEASE_BRANCH` branch

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
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/framework/release_notes/README.md)
for details on where to add DevTools release notes to Flutter website and how to test them.

- Follow the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/framework/release_notes/README.md)
to add release notes to Flutter website
  - On the `$DEVTOOLS_RELEASE_BRANCH` copy the release notes from [NEXT_RELEASE_NOTES.md](./release_notes/NEXT_RELEASE_NOTES.md)
    - These are the release notes you will submit through the flutter/website PR.
  - make sure to also follow the instructions to test them.


[1]: ../packages/devtools_app/lib/src/framework/release_notes/release-notes-next.md

### Upload the DevTools binary to CIPD
- Use the update.sh script to build and upload the DevTools binary to CIPD:
   ```shell
   TARGET_COMMIT_HASH=<Commit hash for the version bump commit in DevTools>
   ```

   ```shell
   cd $LOCAL_DART_SDK && \
   git rebase-update && \
   third_party/devtools/update.sh $TARGET_COMMIT_HASH;
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
git checkout $DEVTOOLS_NEXT_BRANCH
git push -u origin $DEVTOOLS_NEXT_BRANCH
```

From the git GUI tool or from github.com directly:
1. Create a PR.
2. Receive an LGTM, squash and commit.
