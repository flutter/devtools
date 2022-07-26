Panes in this folder should not depend on each other.

If they need to share code, move the code to `memory/primitives` (if it is one library or less),
or to `memory/shared` (if it is more than one library).
