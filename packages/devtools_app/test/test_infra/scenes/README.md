Scenes allow you to define application state that can be both used for testing and
run as an application.

To generate scene runners:
```
flutter pub run build_runner build --delete-conflicting-outputs
```

To run:
```
flutter run -t test/test_infra/scenes/hello.stager_app.g.dart -d macos
```

Configuration for VSCode:
```
{
    "name": "my-scene",
    "cwd": "devtools_app",
    "request": "launch",
    "type": "dart",
    "program": "test/scenes/memory/default.stager_app.g.dart",
    "deviceId": "macos"
},
```

