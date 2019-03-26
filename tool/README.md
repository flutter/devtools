---
title: Publishing Devtool
---

* toc
{:toc}

# How to release the next version of DevTool.

Create a branch for your release. Below we're creating release 0.0.15, with all the PRs. 

# Update master branch and create a local release branch
```shell
cd ~/devtools-git/devtools

checkout master

git pull upstream master

git checkout -b release_0_0_15

cd packages/devtools
```

# Update the release number in two files:
- **packages/devtools/pubspec.yaml**

Change the ```version version: 0.0.15``` to ```version version: 0.0.15```

- **packages/devtools/lib/devtools.dart**

Change the ```const String version = '0.0.14';``` to ```const String version = '0.0.15';```

# Update the CHANGELOG.md
- **packages/devtools/CHANGELOG.md**

Add the release number and date followed by the features or changes e.g.,

```
## 0.0.15 - 2019-04-01
* Added a great feature ...
```

# Push the local branch

```shell
git add lib/devtools.dart 

git add pubspec.yaml

git add CHANGELOG.md

git commit -a -m “Prepare for v0.0.15 release.”

git push origin release_0_0_15
```

# Create the Pull Request
From the git UI tool create the PR, squash and commit.

# Publish DevTool
## Update your master branch from the remote repository
```shell
cd ~/devtools-git/devtools

git pull upstream master
```
## Prep to publish
```shell
./tool/publish.sh
``` 
## Ready to publish.
- ### Verify the package works DevTool
- ### Publish the package
```shell
cd packages/devtools

pub publish
Looks great! Are you ready to upload your package (y/n)? y
```
- ### Revert the change to .gitignore
```shell
git checkout .gitignore

~/devtools-git/devtools
```
- ### Now create the tag for this release and push to the remote repository.
```shell
git tag -a v0.0.15 -m "DevTool 0.0.15"

git push upstream v0.0.15
```