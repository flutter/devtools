<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# Triage

## The Process

DevTools issues are triaged weekly as time allows or at a dedicated time set aside by the triager.
The triager is assigned by an automatic rotation of DevTools team members. 

## Quick links
- [Untriaged issues](https://github.com/flutter/devtools/issues?q=is%3Aopen+is%3Aissue+-label%3AP0%2CP1%2CP2%2CP3)
- [Reproduce to verify issues](https://github.com/flutter/devtools/labels/reproduce%20to%20verify)
(issues that need to be manually reproduced in order to verify validity)
- [flutter/flutter issues related to DevTools](https://github.com/flutter/flutter/labels/d%3A%20devtools)

## Triager responsibilities

The triager should spend about ~1 hour per week on maintaining the health of the DevTools repository.

1. Triage any [new flutter/devtools issues](https://github.com/flutter/devtools/issues?q=is%3Aopen+is%3Aissue+-label%3AP0%2CP1%2CP2%2CP3)
by applying [proper labels](#label-the-issue) and [assigning priority](#prioritize-the-issue).
2. Triage any new [flutter/flutter issues related to DevTools](https://github.com/flutter/flutter/labels/d%3A%20devtools).
Transfer any issues to the `flutter/devtools` repo that should be tracked on our own issue tracker, and close issues you
find that are obsolete.
3. Try to reproduce any issues with the [reproduce to verify](https://github.com/flutter/devtools/labels/reproduce%20to%20verify) label.
4. Spend at least 20 minutes [cleaning up the issue backlog](#clean-up-the-issue-backlog).
5. Look through the DevTools discord [channel](https://discord.com/channels/608014603317936148/958862085297672282) for any recent user
questions or concerns that require a response.

### Label the issue

* Add labels for its proper category or categories ( “screen: inspector", “screen: network", “bug”, etc.)
* Add cost labels ("cost: low", "cost: medium", etc.) if you have a good idea of how much work it will
take to resolve this issue. Leave the cost label off if you do not know.
* Add label “waiting for customer response” if you requested more details from reporter
* Add label “fix it friday” if the issue should be fixed and looks easy to fix
* Add label "good first issue" if the issue looks like an easy starter bug for a new contributor

### Prioritize the issue

Follow the prioritization rubric [here](https://github.com/flutter/flutter/blob/master/docs/contributing/issue_hygiene/README.md#priorities).
If the issue requires specific expertise, tag a product area owner (see below) in a comment and ask them to take a look. 
If the issue is actively being worked on or if it needs immediate / almost-immediate attention (P0, P1), assign the issue
to a product area owner.

Here are some suggested owners by product area:
* **Flutter Inspector**: @elliette
* **Performance**: @kenzieschmoll
* **CPU Profiler**: @kenzieschmoll or @bkonyi
* **Memory**: @kenzieschmoll or @bkonyi
* **Network**: @elliette or @bkonyi
* **Logging**: @elliette or @bkonyi
* **VM Tools**: @bkonyi
* **Debugger**: @elliette
* **DevTools extensions**: @kenzieschmoll
* **Tooling integrations with VS Code**: @DanTup
* **Tooling integrations with IntelliJ or Android Studio**: @helin24 or @jwren

For anything else that requires immediate attention but does not fit into one of
the above areas, please tag @kenzieschmoll or @elliette.

**Ping the [hackers-devtools](https://discord.com/channels/608014603317936148/1106667330093723668) discord channel
about issues marked “severe: …” or “P0”.**

### Clean up the issue backlog

This step is to ensure the health of the [DevTools issue backlog](https://github.com/flutter/devtools/issues) over time.
There are a couple of things to do as part of the backlog clean up work:
- Close any obsolete issues. Recommendation: start with the oldest issues first since these are the most likely to be stale.
- Add good candidates for product excellence / quality work to the 
[DevTools Product Excellence project](https://github.com/orgs/flutter/projects/157). This project feeds monthly milestone
planning for ongoing P.E. work.
