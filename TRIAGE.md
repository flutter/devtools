# Triage

## The Process

DevTools issues are triaged as time allows throughout the week, and during a dedicated triage meeting that occurs weekly.
During the triage meeting, new and existing issues are categorized, prioritized, and / or commented on to provide updates
or gather clarification.

The DevTools discord [channel](https://discord.com/channels/608014603317936148/958862085297672282) is also scrubbed for
any recent user questions / concerns that require a response.

## DevTools Issues

Queue: https://github.com/flutter/devtools/issues?q=is%3Aopen+is%3Aissue+-label%3AP0%2CP1%2CP2%2CP3

For each issue, perform all of these tasks that apply:

### Label/project the issue:
* Add labels for its proper category or categories ( “Inspector page”, “debugger page”, “bug”, etc.)
* Add label “waiting for customer response” if you requested more details from reporter
* Add label “fix it friday” if the issue should be fixed and looks easy to fix
* Add label "good first issue" if the issue looks like an easy starter bug for a new contributor

### Prioritize the issue. 

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

## Related Flutter Issues

flutter/flutter issues relating to DevTools:
https://github.com/flutter/flutter/issues?q=is%3Aopen+label%3A%22d%3A+devtools%22+++no%3Amilestone+ 

Ping the [hackers-devtools](https://discord.com/channels/608014603317936148/1106667330093723668) discord channel about issues marked “severe: …” or “P0”. 
