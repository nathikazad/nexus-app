# nx_time

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Unified calendar

Navigation is Tasks → Calendar → Goals → Today. Tasks is the opening tab.
Calendar is a dedicated week/day planning agenda with open tasks, planned actions,
events and birthdays. Resolved tasks and actual action logs are excluded.
The hamburger menu opens History: the original weekly action/log timeline and
statistics, plus tasks indexed by completion time.

Use the calendar's add button for an Event, Meet, Task, or birthday. Birthday
entry uses a single `YYYY-MM-DD` / `--MM-DD` input and can select an existing
Person. Meetings can link an existing Person and Place. Existing relationships
are preserved on edits. Event attendance is a linked Goto: “Plan to go” checks
for an existing attendance record before creating one. Attendance details edit
scheduled/actual times, status, and notes separately.

Tasks expose only due_at and completed_at as dates; clearing due_at sends an
explicit deletion. Completion writes include the device's local time; the server
preserves the original completion on repeated done writes and clears it on
reopening. Task details show completion, due time, and JSON status/due-date history.
Open overdue Tasks remain in the current task list; calendar entries stay at due_at.

The new `getKgqlCalendar` endpoint must be deployed before this client. The feed
uses the selected domain explicitly, with errors visible rather than falling
back to incomplete legacy results. Schedule and Actual history switch the Action
time basis. Birthdays recur as date markers, with February 29 observed on
February 28 in non-leap years. No yearly birthday models are created.

Focused tests:

```sh
flutter test test/domain test/data/calendar test/data/tasks/task_mapper_test.dart \
  test/data/action/action_mapper_test.dart test/features/tasks \
  test/features/calendar test/widget/calendar
```

## Local simulator verification

`tool/calendar_demo.dart` is a debug-only entrypoint using the full four-tab shell against a local GraphQL server at `127.0.0.1:55440`. It uses fixture
user/domain 3, skips login, and never changes production `main.dart`. The preview skips production login; AI/voice services are not supplied by the
local fixture backend. Goals and Today use their real screens.
The isolated PostgreSQL database is `nexus_task_slim_test` on port 55439.
Demo records are explicitly prefixed `DEMO`.

Plannable support is discovered from Action schema mixins, including inherited
membership. Editing an existing plannable from the old Action editor opens the
shared calendar editor so actual and scheduled times remain separate.

For this Xcode simulator installation, build using the generated Flutter config
with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`; the default universal simulator build
requests an x86_64 Flutter engine that is not present in this local SDK cache.
