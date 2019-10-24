!/bin/bash
echo 'start web'
cd packages/devtools_app
flutter packages get

alias build_runner="flutter pub run build_runner"
build_runner serve web