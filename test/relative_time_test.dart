import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/core/utils/relative_time.dart';

void main() {
  final now = DateTime(2026, 10, 21, 15, 0);

  test('formate les dates comme dans la maquette Notifications', () {
    expect(formatRelativeTime(now.subtract(const Duration(seconds: 20)), now: now), "À l'instant");
    expect(formatRelativeTime(now.subtract(const Duration(minutes: 10)), now: now), '10 min');
    expect(formatRelativeTime(now.subtract(const Duration(hours: 2)), now: now), 'Il y a 2h');
    expect(formatRelativeTime(DateTime(2026, 10, 20, 18, 45), now: now), 'Hier, 18:45');
    expect(formatRelativeTime(DateTime(2026, 10, 18, 9, 0), now: now), 'Il y a 3j');
    expect(formatRelativeTime(DateTime(2026, 9, 1, 9, 0), now: now), '01/09/2026');
  });

  test("isToday distingue aujourd'hui d'hier", () {
    expect(isToday(DateTime(2026, 10, 21, 0, 5), now: now), isTrue);
    expect(isToday(DateTime(2026, 10, 20, 23, 59), now: now), isFalse);
  });
}
