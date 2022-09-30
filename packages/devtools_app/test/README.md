DevTools tests are grouped by their respective screen (if applicable). If a test is for feature that does not belong to
a single screen, it should be placed inside `test/shared/`.

Other directories of interest:
- `test/test_infra/test_data/`: stubbed test data to be used across tests.
- `test/test_infra/`: test driver and environment logic to be used across tests.
- `test/test_utils/`: testing utilities shared across tests.