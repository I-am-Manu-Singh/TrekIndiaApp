import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String roomId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_chats',
      'Trip Group Chats',
      channelDescription: 'Notifications for trip group messages',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      senderName,
      message,
      notificationDetails,
      payload: roomId,
    );
  }

  static Future<void> showWorkoutNotification({
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_workouts',
      'Trip Conditioning',
      channelDescription: 'Active workout progress and instructions',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: progress != null,
      maxProgress: maxProgress ?? 100,
      progress: progress ?? 0,
      ongoing: true,
      onlyAlertOnce: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentAlert: false, presentSound: false),
    );

    await _notificationsPlugin.show(
      999, // Fixed ID for active workout
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> clearWorkoutNotifications() async {
    await _notificationsPlugin.cancel(999);
  }

  static Future<void> showRefundNotification({
    required String tripName,
    required String bookingId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_refunds',
      'Trip Refunds',
      channelDescription: 'Notifications for trip refunds and cancellations',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _notificationsPlugin.show(
      bookingId.hashCode,
      'Refund Ready: $tripName',
      'Your refund advice for $tripName is now ready for download in the dashboard.',
      notificationDetails,
      payload: 'refund_$bookingId',
    );
  }

  static RealtimeChannel? _bookingChannel;

  static void listenToBookingChanges() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _bookingChannel != null) return;

    _bookingChannel = Supabase.instance.client.channel('public:bookings')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'bookings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) async {
          final oldStatus = payload.oldRecord['status'];
          final newStatus = payload.newRecord['status'];
          
          if (oldStatus != 'cancelled' && newStatus == 'cancelled') {
            // Fetch trip title
            try {
              final tripId = payload.newRecord['trip_id'];
              final tripRes = await Supabase.instance.client.from('trips').select('title').eq('id', tripId).single();
              
              showRefundNotification(
                tripName: tripRes['title'] ?? 'Trip',
                bookingId: payload.newRecord['id'],
              );
            } catch (_) {}
          }
        },
      )
      ..subscribe();
  }

  static String? activeRoomId;
  static RealtimeChannel? _messageChannel;

  static void listenToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _messageChannel != null) return;

    _messageChannel = Supabase.instance.client.channel('public:chat_messages')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        callback: (payload) async {
          final newMessage = payload.newRecord;
          if (newMessage['sender_id'] == user.id) return;
          if (newMessage['room_id'] == activeRoomId) return;

          try {
            final senderId = newMessage['sender_id'];
            final profileResponse = await Supabase.instance.client
                .from('profiles')
                .select('full_name, role')
                .eq('id', senderId)
                .single();
                
            String senderName = profileResponse['full_name'] ?? 'User';
            if (profileResponse['role'] == 'admin') {
              senderName = 'Admin ($senderName)';
            }

            showMessageNotification(
              senderName: senderName,
              message: newMessage['content'] ?? '',
              roomId: newMessage['room_id'] ?? '',
            );
          } catch (e) {
            // Silently fail
          }
        },
      )
      ..subscribe();
  }
}
