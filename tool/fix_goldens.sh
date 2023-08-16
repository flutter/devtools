#!/bin/bash -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR/.."

help()
{
   # Display Help
   >&2 echo "A helper script for downloading and applying golden fixes, when they are broken."
   >&2 echo
   >&2 echo "Syntax: fix_goldens.sh RUN_ID"
   >&2 echo "RUN_ID     The ID of the workflow run where the goldens are failing"
   >&2 echo "h     Print this Help."
   >&2 echo
}

if [ $# -gt 1 ]
  then
    >&2 echo "ERROR: $0 takes only 1 argument"
    help
    exit 1
fi

if [ -z "$1" ]
  then
    >&2 echo "ERROR: Expected a RUN_ID"
    help
    exit 1
fi
DOWNLOAD_DIR=$(mktemp -d)

gh run download $RUN_ID -p "*golden_image_failures*" -D "$DOWNLOAD_DIR"
NEW_GOLDENS=$(find $DOWNLOAD_DIR -type f | grep "testImage.png" )
pushd packages/devtools_app/test/
while IFS= read -r GOLDEN ; do
  FILE_NAME=$(basename $GOLDEN | sed "s|_testImage.png$|.png|")
  FOUND_FILES=$(find . -name "$FILE_NAME" )
  FOUND_FILE_COUNT=$(echo -n "$FOUND_FILES" | grep -c '^')

  if [[ $FOUND_FILE_COUNT -ne 1 ]] ; then
    echo $FOUND_FILES
    echo "Multiple goldens found, which should replace $(echo $GOLDEN| sed 's|^.*golden_image_failures[^/]*/||')"
    
    select SELECTED_FILE in $FOUND_FILES
    do
      DEST_PATH="$SELECTED_FILE"
      break;
    done </dev/tty
  else
    DEST_PATH=$FOUND_FILES
  fi
  mv "$GOLDEN" "$DEST_PATH"
done <<< "$NEW_GOLDENS"

echo "Done updating $(echo -n "$NEW_GOLDENS" | grep -c '^') lines"
if [[ $ERROR_COUNTER -gt 0 ]] ; then
  echo "ERROR: $ERROR_COUNTER failed golden updates"
fi

