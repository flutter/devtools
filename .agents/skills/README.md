# Agent Skills

This directory contains AI agent skills for this repository.

## Validation

To ensure skills meet the required specification, they are automatically validated in pre-submit checks.
You should also validate your skills locally before submitting a review.

### Running the Linter Locally

To validate skills locally before review, run the linter from the root of the repository:

```bash
dart run dart_skills_lint:cli
```

This will use the configuration in `dart_skills_lint.yaml` to validate all skills in the `.agents/skills` directory.

Or for a single skill:

```bash
dart run dart_skills_lint:cli --skill .agents/skills/my-skill
```

### Running via Dart Test

Alternatively, you can run the validation as a test from the `tool` directory:

```bash
cd tool && dart test test/validate_skills_test.dart
```

This ensures that the validation logic is executed in the same way as in CI.
