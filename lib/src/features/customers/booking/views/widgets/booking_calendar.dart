import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';

/// Month grid for choosing a day (Monday first, as Australian calendars are).
///
/// Days the client can't book are faint, days with free times carry a dot,
/// and the chosen day is filled. All dates are provider-local wall-clock
/// dates.
class BookingCalendar extends StatelessWidget {
  const BookingCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.lastDay,
    required this.selectedDay,
    required this.hasSlots,
    required this.onSelectDay,
    required this.onChangeMonth,
    this.loading = false,
  });

  /// Any date in the month shown.
  final DateTime month;
  final DateTime today;

  /// Last date the provider takes bookings for.
  final DateTime lastDay;
  final DateTime? selectedDay;
  final bool Function(DateTime day) hasSlots;
  final ValueChanged<DateTime> onSelectDay;

  /// Moves by whole months (-1 / +1).
  final ValueChanged<int> onChangeMonth;

  /// Availability for the month is still loading: dots are hidden.
  final bool loading;

  static const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime get _first => DateTime.utc(month.year, month.month);

  bool get _canGoBack => _first.isAfter(DateTime.utc(today.year, today.month));

  bool get _canGoForward => DateTime.utc(month.year, month.month + 1).isBefore(lastDay.add(const Duration(days: 1)));

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final first = _first;
    final daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  Formatters.monthYear(first),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: scheme.onSurface),
                ),
              ),
            ),
            _MonthButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous month',
              onPressed: _canGoBack ? () => onChangeMonth(-1) : null,
            ),
            const SizedBox(width: 6),
            _MonthButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next month',
              onPressed: _canGoForward ? () => onChangeMonth(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    initial,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Column(
            key: ValueKey(first),
            children: [
              for (var row = 0; row < rows; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(child: _cell(context, row * 7 + column - leading + 1, daysInMonth)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return const AspectRatio(aspectRatio: 1, child: SizedBox());
    final day = DateTime.utc(month.year, month.month, dayNumber);
    final bookable = !day.isBefore(today) && !day.isAfter(lastDay);
    return _DayCell(
      day: day,
      bookable: bookable,
      available: bookable && !loading && hasSlots(day),
      loading: bookable && loading,
      isToday: day == today,
      selected: day == selectedDay,
      onTap: bookable ? () => onSelectDay(day) : null,
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          side: BorderSide(color: scheme.onSurface.withValues(alpha: onPressed == null ? 0.05 : 0.12)),
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.2),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.bookable,
    required this.available,
    required this.loading,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool bookable;
  final bool available;
  final bool loading;
  final bool isToday;
  final bool selected;
  final VoidCallback? onTap;

  static const Duration _animation = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final Color textColor;
    if (selected) {
      textColor = scheme.surface;
    } else if (!bookable) {
      textColor = scheme.onSurface.withValues(alpha: 0.2);
    } else if (available || loading) {
      textColor = scheme.onSurface;
    } else {
      textColor = scheme.onSurface.withValues(alpha: 0.38);
    }

    final state = !bookable
        ? 'unavailable'
        : loading
            ? 'checking availability'
            : available
                ? 'times available'
                : 'fully booked';

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: bookable,
          selected: selected,
          label: '${Formatters.dateLong(day)}, $state${isToday ? ', today' : ''}',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: _animation,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.onSurface : Colors.transparent,
              border: isToday && !selected ? Border.all(color: scheme.primary, width: 1.5) : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onTap!();
                      },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: available || selected ? FontWeight.w800 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      child: AnimatedOpacity(
                        duration: _animation,
                        opacity: available ? 1 : 0,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? scheme.surface : scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
