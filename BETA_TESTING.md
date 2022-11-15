# Beta testing

This page instructs how to test the latest version of DevTools with all experemental features enabled.

If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md)

## Setup and start

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

2. In your terminal `cd` to a folder where you want to clone devtools, and that does not have subfolder `devtools` yet.

3. Start DevTools by cloning the repo, getting Flutter of right version into subdirectory and starting the application:

```bash
git clone https://github.com/flutter/devtools

./devtools/tool/update_flutter_sdk.sh

cd devtools/packages/devtools_app
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true
```

4. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.

## Refresh and start

1. `cd` to the `devtools` directory created in the [Setup and start](#setup-and-start) section.

2. Refresh and run DevTools (it will delete all your local changes!):

```bash
git checkout master;
git reset --hard origin/master

./tool/update_flutter_sdk.sh
cd packages/devtools_app
../../tool/flutter-sdk/bin/flutter pub upgrade

# Start the application:
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true;
```

3. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.
