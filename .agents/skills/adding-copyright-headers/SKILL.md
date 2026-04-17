---
name: adding-copyright-headers
description: Adds copyright headers to files based on file type. Use when creating new files or when asked to verify copyright headers.
---

# Adding Copyright Headers

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

### Shell Scripts (`.sh`)

```bash
# Copyright 20?? The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

## Instructions

1. **New Files**: When creating a new file, you MUST add the appropriate copyright header based on its file extension.
   - Replace `20??` with the current year (e.g., 2026).
2. **Placement**:
   - The copyright header should be at the very top of the file by default.
   - **Exception**: If the file requires a shebang (e.g., `#!/bin/bash` in `.sh` files) or other necessary frontmatter, the copyright header must come **after** the frontmatter, separated by a blank line.
3. **Exclusions**: Copyright headers are **not necessary** in directories that begin with a dot (`.`), such as:
   - `.agents/`
   - `.gemini/`
   - `.github/`
4. **Existing Files**: When editing an existing file, do NOT modify the year in the copyright header. Leave it as it is.
5. **Subsequent Edits**: Subsequent edits should not modify the year.

## Examples (for 2026)

### Shell Script with Shebang
```bash
#!/bin/bash

# Copyright 2026 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```

### Dart File
```dart
// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
```
