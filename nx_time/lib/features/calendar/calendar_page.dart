import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';
import '../../widgets/nx_tab_header.dart';
import '../../widgets/task_row_tile.dart';
import '../activity/activity_detail_page.dart';
import '../tasks/task_detail_page.dart';

/// Selectable days in the week bar (matches reference `tab-calendar.html`).
enum _CalSelection { tue, wed, sat }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  _CalSelection _selection = _CalSelection.wed;
  bool _wedTueActivities = true;
  bool _tueActivities = true;

  static const _sky600 = Color(0xFF0284C7);
  static const _emerald600 = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(
          clockLabel: '9:41 AM',
          title: 'Calendar',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 18, color: _sky600),
              ),
              Expanded(
                child: Text(
                  'Apr 13 – 19',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(SolarLinearIcons.altArrowRight, size: 18, color: _sky600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dayColumnMon(),
                      const SizedBox(width: 6),
                      _dayColumnTue(),
                      const SizedBox(width: 6),
                      _dayColumnWed(),
                      const SizedBox(width: 6),
                      _dayColumnThu(),
                      const SizedBox(width: 6),
                      _dayColumnFri(),
                      const SizedBox(width: 6),
                      _dayColumnSat(),
                      const SizedBox(width: 6),
                      _dayColumnSun(),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Divider(height: 1, color: AppColors.slate200),
              ),
              if (_selection == _CalSelection.wed) _buildWedPanel(),
              if (_selection == _CalSelection.tue) _buildTuePanel(),
              if (_selection == _CalSelection.sat) _buildSatPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barLabels(String letter, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: selected ? AppColors.slate900 : AppColors.slate400,
        ),
      ),
    );
  }

  Widget _stackColumn({
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    bool empty = false,
    List<Widget>? segmentChildren,
  }) {
    assert(empty || segmentChildren != null);
    final Widget bar = empty
        ? DottedBorder(
            options: const RoundedRectDottedBorderOptions(
              radius: Radius.circular(4),
              color: AppColors.slate200,
              dashPattern: [4, 3],
              strokeWidth: 1,
              padding: EdgeInsets.zero,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.slate100,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                width: selected ? 1.5 : 1,
                color: selected ? AppColors.slate900 : AppColors.slate200,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: segmentChildren!),
          );

    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: bar),
        _barLabels(label, selected: selected),
      ],
    );

    if (onTap == null) return Expanded(child: col);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: col,
      ),
    );
  }

  List<Widget> _segments(List<(Color, int)> pairs, {Color? remainder, int remainderFlex = 0}) {
    final out = <Widget>[];
    for (final p in pairs) {
      out.add(Expanded(flex: p.$2, child: Container(color: p.$1)));
    }
    if (remainder != null && remainderFlex > 0) {
      out.add(Expanded(flex: remainderFlex, child: Container(color: remainder)));
    }
    return out;
  }

  Widget _dayColumnMon() {
    return _stackColumn(
      label: 'M',
      segmentChildren: _segments(
        [
          (AppColors.calPurple, 30),
          (AppColors.calGreen, 3),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 30),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 8),
        ],
        remainder: AppColors.calMuted,
        remainderFlex: 21,
      ),
    );
  }

  Widget _dayColumnTue() {
    final selected = _selection == _CalSelection.tue;
    return _stackColumn(
      label: 'T',
      selected: selected,
      onTap: () => setState(() => _selection = _CalSelection.tue),
      segmentChildren: _segments(
        [
          (AppColors.calPurple, 33),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 28),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 12),
        ],
        remainder: AppColors.calMuted,
        remainderFlex: 19,
      ),
    );
  }

  Widget _dayColumnWed() {
    final selected = _selection == _CalSelection.wed;
    return _stackColumn(
      label: 'W',
      selected: selected,
      onTap: () => setState(() => _selection = _CalSelection.wed),
      segmentChildren: _segments(
        [
          (AppColors.calPurple, 29),
          (AppColors.calGreen, 3),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 25),
          (AppColors.calOrange, 4),
          (AppColors.calOlive, 6),
          (AppColors.calBlue, 10),
        ],
        remainder: AppColors.calMuted,
        remainderFlex: 19,
      ),
    );
  }

  Widget _dayColumnThu() {
    return _stackColumn(
      label: 'T',
      segmentChildren: _segments(
        [
          (AppColors.calPurple, 32),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 30),
          (AppColors.calGreen, 3),
          (AppColors.calOrange, 4),
        ],
        remainder: AppColors.calMuted,
        remainderFlex: 27,
      ),
    );
  }

  Widget _dayColumnFri() {
    return _stackColumn(
      label: 'F',
      segmentChildren: _segments(
        [
          (AppColors.calPurple, 29),
          (AppColors.calGreen, 2),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 17),
          (AppColors.calOrange, 4),
          (AppColors.calBlue, 8),
          (AppColors.calOlive, 3),
        ],
        remainder: AppColors.slate100,
        remainderFlex: 33,
      ),
    );
  }

  Widget _dayColumnSat() {
    final selected = _selection == _CalSelection.sat;
    return _stackColumn(
      label: 'S',
      selected: selected,
      empty: true,
      onTap: () => setState(() => _selection = _CalSelection.sat),
    );
  }

  Widget _dayColumnSun() {
    return _stackColumn(
      label: 'S',
      empty: true,
    );
  }

  String _calendarDateLabelForSelection() {
    switch (_selection) {
      case _CalSelection.tue:
        return 'Tue, Apr 14';
      case _CalSelection.wed:
        return 'Wed, Apr 15';
      case _CalSelection.sat:
        return 'Sat, Apr 18';
    }
  }

  String _categoryForCalendarTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('sleep')) return 'Sleep';
    if (t.contains('yoga') || t.contains('stretch')) return 'Exercise';
    if (t.contains('breakfast') || t.contains('lunch') || t.contains('coffee')) return 'Eat';
    if (t.contains('walk')) return 'Outdoors';
    if (t.contains('deep work') || t.contains('meeting') || t.contains('email') || t.contains('design')) {
      return 'Work';
    }
    return 'Activity';
  }

  void _openCalendarActivity(
    BuildContext context, {
    required Color color,
    required String time,
    required String title,
    required String duration,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          args: ActivityDetailArgs(
            title: title,
            categoryLabel: _categoryForCalendarTitle(title),
            accentColor: color,
            dateLabel: _calendarDateLabelForSelection(),
            timeRangeLabel: time,
            durationLabel: duration,
          ),
        ),
      ),
    );
  }

  void _openTaskDetail(BuildContext context, TaskDetailArgs args) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskDetailPage(args: args)),
    );
  }

  Widget _buildWedPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Wednesday, Apr 15',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Row(
                children: [
                  _CalToggleChip(
                    label: 'Activities',
                    selected: _wedTueActivities,
                    onTap: () => setState(() => _wedTueActivities = true),
                  ),
                  const SizedBox(width: 4),
                  _CalToggleChip(
                    label: 'Tasks',
                    selected: !_wedTueActivities,
                    onTap: () => setState(() => _wedTueActivities = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_wedTueActivities) ...[
          _CalActivityRow(
            color: AppColors.calPurple,
            time: '12:00 – 6:55a',
            title: 'Sleep',
            duration: '6h 55m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calPurple, time: '12:00 – 6:55a', title: 'Sleep', duration: '6h 55m'),
          ),
          _CalActivityRow(
            color: AppColors.calGreen,
            time: '7:00 – 7:28a',
            title: 'Yoga',
            duration: '28m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calGreen, time: '7:00 – 7:28a', title: 'Yoga', duration: '28m'),
          ),
          _CalActivityRow(
            color: AppColors.calOrange,
            time: '7:35 – 8:10a',
            title: 'Breakfast',
            duration: '35m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOrange, time: '7:35 – 8:10a', title: 'Breakfast', duration: '35m'),
          ),
          _CalActivityRow(
            color: AppColors.calBlue,
            time: '8:15 – 11:30a',
            title: 'Deep work — API',
            duration: '3h 15m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calBlue, time: '8:15 – 11:30a', title: 'Deep work — API', duration: '3h 15m'),
          ),
          _CalActivityRow(
            color: AppColors.calOrange,
            time: '11:30 – 12:10p',
            title: 'Lunch',
            duration: '40m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOrange, time: '11:30 – 12:10p', title: 'Lunch', duration: '40m'),
          ),
          _CalActivityRow(
            color: AppColors.calOlive,
            time: '12:15 – 12:50p',
            title: 'Walk',
            duration: '35m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOlive, time: '12:15 – 12:50p', title: 'Walk', duration: '35m'),
          ),
          _CalActivityRow(
            color: AppColors.calBlue,
            time: '1:00 – 3:30p',
            title: 'Meetings + review',
            duration: '2h 30m',
            showBorder: false,
            onTap: () => _openCalendarActivity(context, color: AppColors.calBlue, time: '1:00 – 3:30p', title: 'Meetings + review', duration: '2h 30m'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              'tap any row to view activity detail',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                TaskRowTile(
                  title: 'Review Q3 Analytics',
                  subtitle: 'Growth › Reports',
                  durationLabel: '45m',
                  done: true,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Review Q3 Analytics', subtitle: 'Growth › Reports', durationLabel: '45m'),
                  ),
                ),
                TaskRowTile(
                  title: 'Reply to investors',
                  subtitle: 'Admin',
                  durationLabel: '15m',
                  done: true,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Reply to investors', subtitle: 'Admin', durationLabel: '15m'),
                  ),
                ),
                TaskRowTile(
                  title: 'Draft weekly newsletter',
                  subtitle: 'Content › Newsletter',
                  durationLabel: '1h',
                  done: false,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Draft weekly newsletter', subtitle: 'Content › Newsletter', durationLabel: '1h'),
                  ),
                ),
                TaskRowTile(
                  title: 'Gym: Upper Body',
                  subtitle: 'Personal › Health',
                  durationLabel: '1h 15m',
                  done: false,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Gym: Upper Body', subtitle: 'Personal › Health', durationLabel: '1h 15m'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTuePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tuesday, Apr 14',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Day complete',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _emerald600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _CalToggleChip(
                    label: 'Activities',
                    selected: _tueActivities,
                    onTap: () => setState(() => _tueActivities = true),
                  ),
                  const SizedBox(width: 4),
                  _CalToggleChip(
                    label: 'Tasks',
                    selected: !_tueActivities,
                    onTap: () => setState(() => _tueActivities = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_tueActivities) ...[
          _CalActivityRow(
            color: AppColors.calPurple,
            time: '11:15p – 6:10a',
            title: 'Sleep',
            duration: '6h 55m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calPurple, time: '11:15p – 6:10a', title: 'Sleep', duration: '6h 55m'),
          ),
          _CalActivityRow(
            color: AppColors.calGreen,
            time: '6:20 – 6:55a',
            title: 'Stretch + mobility',
            duration: '35m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calGreen, time: '6:20 – 6:55a', title: 'Stretch + mobility', duration: '35m'),
          ),
          _CalActivityRow(
            color: AppColors.calOrange,
            time: '7:00 – 7:40a',
            title: 'Breakfast + coffee',
            duration: '40m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOrange, time: '7:00 – 7:40a', title: 'Breakfast + coffee', duration: '40m'),
          ),
          _CalActivityRow(
            color: AppColors.calBlue,
            time: '8:00a – 12:10p',
            title: 'Deep work — design review',
            duration: '4h 10m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calBlue, time: '8:00a – 12:10p', title: 'Deep work — design review', duration: '4h 10m'),
          ),
          _CalActivityRow(
            color: AppColors.calOrange,
            time: '12:15 – 12:55p',
            title: 'Lunch',
            duration: '40m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOrange, time: '12:15 – 12:55p', title: 'Lunch', duration: '40m'),
          ),
          _CalActivityRow(
            color: AppColors.calOlive,
            time: '1:00 – 1:45p',
            title: 'Walk',
            duration: '45m',
            onTap: () => _openCalendarActivity(context, color: AppColors.calOlive, time: '1:00 – 1:45p', title: 'Walk', duration: '45m'),
          ),
          _CalActivityRow(
            color: AppColors.calBlue,
            time: '2:00 – 5:30p',
            title: 'Meetings + email',
            duration: '3h 30m',
            showBorder: false,
            onTap: () => _openCalendarActivity(context, color: AppColors.calBlue, time: '2:00 – 5:30p', title: 'Meetings + email', duration: '3h 30m'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              'tap any row to view activity detail',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                TaskRowTile(
                  title: 'Team standup notes',
                  subtitle: 'Work › Sync',
                  durationLabel: '12m',
                  done: true,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Team standup notes', subtitle: 'Work › Sync', durationLabel: '12m'),
                  ),
                ),
                TaskRowTile(
                  title: 'Ship hotfix v1.2',
                  subtitle: 'Platform › Release',
                  durationLabel: '1h',
                  done: true,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Ship hotfix v1.2', subtitle: 'Platform › Release', durationLabel: '1h'),
                  ),
                ),
                TaskRowTile(
                  title: 'Plan next sprint',
                  subtitle: 'Work › Roadmap',
                  durationLabel: '45m',
                  done: false,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Plan next sprint', subtitle: 'Work › Roadmap', durationLabel: '45m'),
                  ),
                ),
                TaskRowTile(
                  title: 'Email contractor',
                  subtitle: 'Home › Reno',
                  durationLabel: '30m',
                  done: false,
                  onTap: () => _openTaskDetail(
                    context,
                    const TaskDetailArgs(title: 'Email contractor', subtitle: 'Home › Reno', durationLabel: '30m'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSatPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saturday, Apr 18',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tasks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            children: [
              TaskRowTile(
                title: 'Farmers market run',
                subtitle: 'Errands › Food',
                durationLabel: '50m',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(title: 'Farmers market run', subtitle: 'Errands › Food', durationLabel: '50m'),
                ),
              ),
              TaskRowTile(
                title: 'Call parents',
                subtitle: 'Personal',
                durationLabel: '25m',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(title: 'Call parents', subtitle: 'Personal', durationLabel: '25m'),
                ),
              ),
              TaskRowTile(
                title: 'Movie night — pick film',
                subtitle: 'Social · 7:30p',
                durationLabel: '2h',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(title: 'Movie night — pick film', subtitle: 'Social · 7:30p', durationLabel: '2h'),
                ),
              ),
              TaskRowTile(
                title: 'Tidy garage shelf',
                subtitle: 'Home › Storage',
                durationLabel: '35m',
                done: false,
                onTap: () => _openTaskDetail(
                  context,
                  const TaskDetailArgs(title: 'Tidy garage shelf', subtitle: 'Home › Storage', durationLabel: '35m'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalToggleChip extends StatelessWidget {
  const _CalToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate900 : AppColors.slate100,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalActivityRow extends StatelessWidget {
  const _CalActivityRow({
    required this.color,
    required this.time,
    required this.title,
    required this.duration,
    required this.onTap,
    this.showBorder = true,
  });

  final Color color;
  final String time;
  final String title;
  final String duration;
  final bool showBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: showBorder
                ? const Border(bottom: BorderSide(color: AppColors.slate200, width: 0.5))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 18),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 88,
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                duration,
                style: const TextStyle(fontSize: 12, color: AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
