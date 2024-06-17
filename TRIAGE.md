# Triage

## The Process

If you are the devtools triage rotation on-call, you are expected to triage issues that appeared/updated during the week (it is ok to triage all of them at the end of the week).

You are also expected to monitor the DevTools discord [channel](https://discord.com/channels/608014603317936148/958862085297672282) for user questions / concerns.

## DevTools Issues

Queue: https://github.com/flutter/devtools/issues?q=is%3Aopen+is%3Aissue+-label%3AP0%2CP1%2CP2%2CP3%2CP4%2CP5%2CP6 

For each new issue that comes in, perform all of these tasks that apply:

### Label/project the issue:
* Add labels for its proper category or categories ( “Inspector page”, “debugger page”, “bug”, etc.)
* Add label “waiting for customer response” if you requested more details from reporter
* Add label “fix it friday” if the issue should be fixed and looks easy to fix
* Add to project [go/dart-devtools-ux-issues](https://github.com/orgs/flutter/projects/54/settings) if the issue is cross-screen issue

### Prioritize the issue. 

Follow the prioritization rubric [here](https://github.com/flutter/flutter/blob/master/docs/contributing/issue_hygiene/README.md#priorities).

Tag the area owner in a comment if the issue requires specific expertise. Assign to an owner if the issue is a work in process or if the issue needs immediate / almost-immediate attention (P0, P1).

## Related Flutter Issues

flutter/flutter issues relating to DevTools:
https://github.com/flutter/flutter/issues?q=is%3Aopen+label%3A%22d%3A+devtools%22+++no%3Amilestone+ 

Ping the [hackers-devtools](https://discord.com/channels/608014603317936148/1106667330093723668) discord channel about issues marked “severe: …” or “P0”. 
