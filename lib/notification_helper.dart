import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> scheduleSpotReminder({
  required String title,
  required String body,
  required DateTime time,
  required int id,
}) async {
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(time, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'spot_channel_id',
        'Spot Reminders',
        channelDescription: '提醒使用者即將前往的景點',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}
