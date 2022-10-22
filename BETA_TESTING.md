# Beta testing

This page instructs how to test the latest version of DevTools with all experemental features enabled.

If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md)

## Setup and start

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

2. In your terminal `cd` to a folder where you want to clone devtools, and that does not have subfolder `devtools` yet.

3. Start DevTools:

```bash
# Clone the repo:
git clone https://github.com/flutter/devtools.git;

# Get local Flutter of the correct version:
./devtools/tool/update_flutter_sdk.sh;

# Start the application:
cd devtools/packages/devtools_app;
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true;
```

4. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.

## Refresh and start

1. `cd` to the `devtools` directory created in the [Setup and start](#setup-and-start) section.

2. Refresh and run DevTools (it will delete all your local changes!):

```bash
# Checkout the master branch and ensure it is at the most recent change:
git checkout master;
git reset --hard origin/master; # this line will remove all local changes or commits on your branch

# Make sure all dependencies have correct version:
./tool/update_flutter_sdk.sh;
cd packages/devtools_app;
../../tool/flutter-sdk/bin/flutter pub upgrade;

# Start the application:
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true;
```

3. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.
