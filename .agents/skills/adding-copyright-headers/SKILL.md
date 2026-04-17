---
name: adding-copyright-headers
description: Adds copyright headers to files based on file type. Use when creating new files or when asked to verify copyright headers.
---

# Adding Copyright Headers

This skill provides instructions for adding copyright headers to source files in this repository based on their file type.

## Formats

### Dart Files (`.dart`)

```dart
// Copyright 20?? The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

### YAML Files (`.yaml`)

```yaml
# Copyright 20?? The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

### HTML Files (`.html`) and Markdown Files (`.md`)

```html
<!--
Copyright 20?? The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
```

## Instructions

1. **New Files**: When creating a new file, you MUST add the appropriate copyright header at the very top of the file based on its file extension.
   - Replace `20??` with the current year (e.g., 2026).
2. **Existing Files**: When editing an existing file, do NOT modify the year in the copyright header. Leave it as it is.
3. **Subsequent Edits**: Subsequent edits should not modify the year.

## Examples (for 2026)

### Dart
```dart
// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

### YAML
```yaml
# Copyright 2026 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

### HTML / Markdown
```html
<!--
Copyright 2026 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
```
