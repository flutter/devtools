## How to release the next version of DevTools

### Configure/Refresh environment

Make sure:
1. You have a local checkout of the Dart SDK
   - (for getting started instructions, see [sdk/CONTRIBUTING.md](https://github.com/dart-lang/sdk/blob/main/CONTRIBUTING.md)).
2. Ensure your .bashrc sets `$LOCAL_DART_SDK`
    
   ```shell 
   DART_SDK_REPO_DIR=<Path to cloned dart sdk>
   export LOCAL_DART_SDK=$DART_SDK_REPO_DIR/sdk
   ```
3. The local checkout is at `main` branch:
   - `git rebase-update`.
4. Your Flutter version is equal to the one in flutter_version.txt. If not, fix it using one of:
    - Run `./tool/update_flutter_sdk.sh` from the main devtools directory
    - Switch Flutter version by running 'git checkout <version in flutter_version.txt>' in Flutter directory.
5. You have goma [configured](http://go/ma-mac-setup). 

### Prepare the release

#### Create a branch for your release.

```shell
cd ~/path/to/devtools
```

```shell
git checkout master && \
git pull upstream master && \
git checkout -b release_2.7.0;
```

#### Update the DevTools version number

Run the `tool/update_version.dart` script to update the DevTools version.
- For regular monthly releases, use `minor`:
   ```shell
   dart tool/update_version.dart auto --type minor
   ```
- To manually set the version:
   ```shell
   dart tool/update_version.dart manual --new-version 1.2.3
   ```
- To automatically update the version by `major`, `minor`, `patch`, or `dev`:
   ```shell
   dart tool/update_version.dart auto --type patch
   ```

Verify:
* that this script updated the pubspecs under packages/
* updated all references to those packages.
*  make sure that the version constant in `packages/devtools_app/lib/devtools.dart` was updated

These packages always have their version numbers updated in lock, so we don't have to worry about versioning.

#### Update the CHANGELOG.md (for non-dev releases)

* Use the tool `generate-changelog` to automatically update the `packages/devtools/CHANGELOG.md` file.

   ```shell
   cd ~/path/to/devtools && \
   dart tool/bin/repo_tool.dart generate-changelog;
   ```

* The `generate-changelog` script is
intended to do the bulk of the work, but still needs manual review.
* Verify
   * that the version for the CHANGELOG entry was correctly generated
   * that the entries don't have any syntax errors. 

#### Push the local branch

```shell
NEW_DEVTOOLS_VERSION=2.7.0 # Change this to the new version
```

```shell
git add . && \
git commit -m “Prepare for $NEW_DEVTOOLS_VERSION release.” && \
git push origin release_$NEW_DEVTOOLS_VERSION;
```

From the git GUI tool or from github.com directly:
1. Create a PR.
2. Add the entry about the created PR to the CHANGELOG.md manually, and push to the PR.
3. Receive an LGTM, squash and commit.

### Test the release

- Checkout the commit you just created,
   - or remain on the branch you just landed the prep PR from.
   ```shell
   git checkout 8881a7caa9067471008a8e00750b161f53cdb843
   ```

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

### Upload the DevTools binary to CIPD
- `TARGET_COMMIT_HASH` should be the commit hash you want to release DevTools from
   - this should match the
commit hash for the tag you just created
   - and the [update.sh](https://github.com/dart-lang/sdk/blob/master/third_party/devtools/update.sh)
script,
   ```shell
   TARGET_COMMIT_HASH=<Commit hash for the version bump commit>
   ```

- build and upload the DevTools binary to CIPD.

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
   - set the `devtools_rev` entry to the `TARGET_COMMIT_HASH.
   - See this [example CL](https://dart-review.googlesource.com/c/sdk/+/215520) for reference.


- Build the dart sdk locally to do this.

   ```shell
   cd $LOCAL_DART_SDK && \
   gclient sync -D && \
   ./tools/build.py -mrelease -ax64 create_sdk;
   ```

- Verify that running `dart devtools` launches the version of DevTools you just released. 
   - For non-OSX
      ```shell
      out/ReleaseX64/dart-sdk/bin/dart devtools
      ```
   - for OSX
      ```shell
      xcodebuild/ReleaseX64/dart-sdk/bin/dart devtools
      ```

- If the version of DevTools you just published to CIPD loads properly
   - push up the SDK CL for review.
      ```shell
      git add . && \
      git commit -m "Bump DevTools DEP to 2.16.0" && \
      git cl upload -s;
      ```

### Publish package:devtools_shared on pub

`package:devtools_shared` is the only DevTools package that is published on pub.

- From the `devtools/packages/devtools_shared` directory, run:
   ```shell
   flutter pub publish
   ```

### Write release notes for the release
Release notes should contain details about the user-facing changes included in the release.
These notes are shown directly in DevTools when a user opens a new version of DevTools.

1. Request the team to verify their important user facing changes are documented in 
   [release-notes-next.md][1].

2. See the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/framework/release_notes/README.md)
for details on where to add DevTools release notes to Flutter website and how to test them.
   
3. Copy the content of [release-notes-template.md](../packages/devtools_app/lib/src/framework/release_notes/release-notes-template.md) to [release-notes-next.md][1], to contain
   draft for the next release.

[1]: ../packages/devtools_app/lib/src/framework/release_notes/release-notes-next.md
