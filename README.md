

## start web

```bash
cd packages/devtools_app
alias build_runner="flutter pub run build_runner"

flutter packages get
build_runner serve web
```

## start app

```bash
cd packages/devtools_app

flutter config --enable-web
flutter run -d chrome
```

## features

* add logging filter
* hide system log
