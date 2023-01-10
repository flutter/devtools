# What is an "offline" integration test?

Tests in this directory will run DevTools without connecting it to a live application.
Integration tests in this directory will load offline data for testing. This is useful
for testing features that will not have stable data from a live application. For example,
the Performance screen timeline data will never be stable with a live applicaiton, so
loading offline data allows for screenshot testing without flakiness.

See also `integration_test/test/live_connection`, which contains tests that run DevTools
and connect it to a live Dart or Flutter application. 
