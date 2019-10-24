!/bin/bash
echo 'start web'
cd packages/devtools_app

alias build_runner="flutter pub run build_runner"
build_runner serve web