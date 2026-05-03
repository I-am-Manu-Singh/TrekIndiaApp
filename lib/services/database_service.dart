import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import 'supabase_service.dart';

class DatabaseService {
  final _client = SupabaseService().client;
  static List<TripCategory> _cachedCategories = [];

  Future<List<Trip>> fetchTrips() async {
    try {
      final response = await _client.from('trips').select('*, trip_packages(*), pickup_options(*)');
      return (response as List).map((e) => Trip.fromJson(e)).toList();
    } catch (e) {
      debugPrint('SYSTEM ADVISORY: Database service connection timed out. Error: $e');
      return [];
    }
  }

  Future<List<TripCategory>> fetchCategories() async {
    if (_cachedCategories.isNotEmpty) return _cachedCategories;
    try {
      final response = await _client.from('trip_categories').select().order('display_order', ascending: true);
      final List<TripCategory> cats = (response as List).map((e) => TripCategory.fromJson(e)).toList();
      
      if (cats.isEmpty) {
        return [
          TripCategory(id: '1', name: 'Adventure Trip', displayOrder: 1),
          TripCategory(id: '2', name: 'Religious Trip', displayOrder: 2),
          TripCategory(id: '3', name: 'Weekend Trip', displayOrder: 3),
          TripCategory(id: '4', name: 'Package', displayOrder: 4, isSpecial: true, badgeLabel: 'VACATION', iconName: 'beach_access', colorHex: '#00BCD4'),
        ];
      }
      
      _cachedCategories = cats;
      return _cachedCategories;
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [
        TripCategory(id: '1', name: 'Adventure Trip', displayOrder: 1),
        TripCategory(id: '2', name: 'Religious Trip', displayOrder: 2),
        TripCategory(id: '3', name: 'Weekend Trip', displayOrder: 3),
        TripCategory(id: '4', name: 'Package', displayOrder: 4, isSpecial: true, badgeLabel: 'VACATION', iconName: 'beach_access', colorHex: '#00BCD4'),
      ];
    }
  }

  Future<Trip?> fetchTripById(String id) async {
    try {
      final response = await _client.from('trips').select('*, trip_packages(*), pickup_options(*)').eq('id', id).maybeSingle();
      if (response == null) return null;
      return Trip.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching trip $id: $e');
      return null;
    }
  }

  Future<List<Trip>> fetchTripsByCategory(String category) async {
    try {
      final response = await _client.from('trips').select('*, trip_packages(*), pickup_options(*)').eq('category', category);
      return (response as List).map((e) => Trip.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching $category trips: $e');
      return [];
    }
  }

  Future<List<Trip>> fetchVacationPackages() async {
    try {
      // Fetch multiple categories for the vacation section
      final response = await _client.from('trips')
          .select('*, trip_packages(*), pickup_options(*)')
          .inFilter('category', ['Package', 'Beach Trip', 'Desh Videsh', 'Bike Trip', 'Car Trip', 'Vacation']);
      return (response as List).map((e) => Trip.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching vacation packages: $e');
      return [];
    }
  }

  Future<List<Gear>> fetchGears() async {
    try {
      final response = await _client.from('gears').select();
      return (response as List).map((e) => Gear.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching gears: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchBlogs() async {
    try {
      final response = await _client.from('blogs').select('*').order('created_at', ascending: false);
      return response as List;
    } catch (e) {
      print('Error fetching blogs: $e');
      return [];
    }
  }

  Future<String?> bookTrip({
    required String tripId,
    required String tripTitle,
    required String fullName,
    required String phoneNumber,
    required int pax,
    required DateTime tripDate,
    required double tripPrice,
    required double pickupPrice,
    required String pickupLocation,
    required double totalPrice,
    required String hikerEmail,
    String? userId,
    List<Map<String, dynamic>> addons = const [],
    List<Map<String, dynamic>> additionalTravelers = const [],
    String? paymentMethod,
    String? paymentProof,
  }) async {
    try {
      final user = _client.auth.currentUser;
      
      // 1. Find or Create Group for this date
      final dateStr = tripDate.toIso8601String().split('T')[0];
      final groups = await _client.from('trip_groups')
          .select('id')
          .eq('trip_id', tripId)
          .eq('departure_date', dateStr);
      
      String? groupId;
      if ((groups as List).isNotEmpty) {
        groupId = groups[0]['id'];
      } else {
        final groupResponse = await _client.from('trip_groups').insert({
          'trip_id': tripId,
          'departure_date': dateStr,
          'group_name': '$tripTitle - $dateStr',
        }).select().single();
        groupId = groupResponse['id'];
      }

      // 2. Prevent duplicate booking
      final existingBooking = await _client.from('bookings')
          .select('id')
          .eq('user_id', userId ?? user?.id ?? '')
          .eq('trip_id', tripId)
          .eq('trip_date', dateStr)
          .maybeSingle();
      
      if (existingBooking != null) return existingBooking['id'];

      final bookingResponse = await _client.from('bookings').insert({
        'user_id': userId ?? user?.id,
        'trip_id': tripId,
        'group_id': groupId,
        'travelers': pax,
        'traveler_details': additionalTravelers,
        'trip_date': dateStr,
        'pickup_location': pickupLocation,
        'trip_price': tripPrice,
        'pickup_price': pickupPrice,
        'total_price': totalPrice,
        'paid_amount': (paymentMethod == 'UPI' || paymentMethod == 'Card') ? totalPrice : 0,
        'payment_status': (paymentMethod == 'UPI') ? 'Verifying' : (paymentMethod == 'Card' ? 'Paid' : 'Pending'),
        'payment_method': paymentMethod,
        'payment_proof_url': paymentProof,
        'hiker_name': fullName,
        'hiker_number': phoneNumber,
        'hiker_email': hikerEmail,
        'hiker_pax': pax,
        'trip_name': tripTitle,
      }).select().single();

      final bookingId = bookingResponse['id'];

      // 3. Add Addons
      if (addons.isNotEmpty) {
        await _client.from('booking_addons').insert(addons.map((a) => {
          'booking_id': bookingId,
          'gear_id': a['gear_id'],
          'quantity': a['quantity'],
          'price_at_booking': a['price']
        }).toList());
      }

      // 4. Update Trip Group Last Message & Send REAL Message
      final welcomeMsg = "📢 Welcome! $fullName has joined the $tripTitle group for $dateStr.";
      await _client.from('trip_groups').update({
        'last_message_content': welcomeMsg,
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', groupId ?? '');

      // Insert into chat_messages so it appears in the chat history
      await _client.from('chat_messages').insert({
        'room_id': groupId,
        'sender_id': userId ?? user?.id, 
        'content': welcomeMsg,
        'message_type': 'text',
      });

      // 4. Notify User
      if (user != null) {
        await createNotification(
          userId: user.id,
          title: 'Booking Confirmed',
          body: 'You have successfully booked $tripTitle for $dateStr.',
          category: 'booking',
        );
      }

      // 5. Notify Admins
      try {
        final admins = await _client.from('profiles').select('id').eq('role', 'admin');
        for (var admin in admins) {
          await createNotification(
            userId: admin['id'],
            title: 'New Booking Alert!',
            body: '${user?.userMetadata?['full_name'] ?? 'A traveler'} just booked $tripTitle.',
            category: 'admin_booking',
          );
        }
      } catch (e) {
        debugPrint('Admin notification error: $e');
      }

      return groupId;
    } catch (e) {
      print('Error booking trip: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    if (groupId.isEmpty) return [];
    try {
      // 1. Fetch participants from bookings
      final participantsRes = await _client
          .from('bookings')
          .select('user_id, profiles!user_id!inner(full_name, avatar_url, role)')
          .eq('group_id', groupId);
      
      // 2. Fetch staff from trip_group_staff
      final staffRes = await _client
          .from('trip_group_staff')
          .select('user_id, profiles!user_id!inner(full_name, avatar_url, role)')
          .eq('group_id', groupId);

      // 3. Combine and Deduplicate
      final List<Map<String, dynamic>> members = [];
      final Set<String> seenIds = {};

      for (var p in (participantsRes as List)) {
        final id = p['user_id'].toString();
        if (!seenIds.contains(id)) {
          members.add({'user_id': id, 'profiles': p['profiles']});
          seenIds.add(id);
        }
      }

      for (var s in (staffRes as List)) {
        final id = s['user_id'].toString();
        if (!seenIds.contains(id)) {
          members.add({'user_id': id, 'profiles': s['profiles']});
          seenIds.add(id);
        }
      }

      return members;
    } catch (e) {
      print('Error fetching members: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembersByTrip(String tripId, String date) async {
    try {
      final groups = await _client.from('trip_groups').select('id').eq('trip_id', tripId).eq('departure_date', date).maybeSingle();
      if (groups == null) return [];
      return fetchGroupMembers(groups['id']);
    } catch (_) {
      return [];
    }
  }

  Future<void> logTrainingSession({
    required String title,
    required int seconds,
    int? calories,
    String? intensity,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.from('training_logs').insert({
        'user_id': user.id,
        'workout_title': title,
        'duration_seconds': seconds,
        'calories_burned': calories ?? 0,
        'intensity_level': intensity ?? 'Medium',
      });
    } catch (e) {
      print('Error logging training: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTrainingLogs() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      final response = await _client
          .from('training_logs')
          .select('*')
          .eq('user_id', user.id)
          .order('completed_at', ascending: false);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Error fetching logs: $e');
      return [];
    }
  }

  Future<void> createSupportInquiry({required String message, String? subject, String? aiContext}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.from('support_inquiries').insert({
        'user_id': user.id,
        'subject': subject,
        'message': message,
        'ai_context': aiContext,
      });
    } catch (e) {
      print('Error creating inquiry: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSupportInquiries() async {
    try {
      final response = await _client
          .from('support_inquiries')
          .select('*, profiles!user_id(full_name, avatar_url)')
          .order('created_at', ascending: false);
      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error fetching inquiries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMySupportInquiries() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      
      final response = await _client
          .from('support_inquiries')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error fetching my inquiries: $e');
      return [];
    }
  }

  Future<void> respondToInquiry(String id, String reply) async {
    try {
      await _client.from('support_inquiries').update({
        'admin_reply': reply,
        'status': 'Resolved',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      print('Error responding to inquiry: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final response = await _client
          .from('profiles')
          .select('full_name, avatar_url, xp, level')
          .order('xp', ascending: false)
          .limit(20);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<void> addXP(int amount) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      
      final profile = await _client.from('profiles').select('xp, level').eq('id', user.id).maybeSingle();
      if (profile == null) return;
      
      int currentXP = int.tryParse(profile['xp']?.toString() ?? '0') ?? 0;
      
      int newXP = currentXP + amount;
      int newLevel = (newXP / 1000).floor() + 1;
      
      await _client.from('profiles').update({
        'xp': newXP,
        'level': newLevel,
      }).eq('id', user.id);
    } catch (e) {
      print('SYSTEM ALERT: Achievement sync failed. Error: $e');
    }
  }

  Future<bool> completeTrip({
    String? userId, 
    String? tripId, 
    String? groupId, 
    String? bookingId,
    double distance = 10.0
  }) async {
    try {
      if (groupId != null) {
        // GROUP COMPLETION LOGIC
        await _client.from('trip_groups').update({
          'status': 'completed',
          'last_message_content': 'Trip marked as COMPLETED. Chat Archived.',
        }).eq('id', groupId);

        await _client.from('bookings').update({
          'status': 'completed',
          'payment_status': 'Paid',
        }).eq('group_id', groupId);

        final participants = await _client.from('bookings').select('user_id').eq('group_id', groupId);
        for (var p in (participants as List)) {
          final uid = p['user_id'];
          if (uid != null) {
            await _updateUserStats(uid, distance);
            await createNotification(
              userId: uid,
              title: 'Trip Completed!',
              body: 'Congratulations! Your trek has been marked as completed. Check your medals!',
              category: 'achievement',
            );
          }
        }
        return true;
      } else if (bookingId != null) {
        // PRECISE BOOKING COMPLETION
        await _client.from('bookings').update({'status': 'completed'})
            .eq('id', bookingId);
        
        if (userId != null) await _updateUserStats(userId, distance);
        return true;
      } else if (userId != null && tripId != null) {
        // FALLBACK: COMPLETION BY USER/TRIP (Any non-cancelled status)
        await _client.from('bookings').update({'status': 'completed'})
            .eq('user_id', userId)
            .eq('trip_id', tripId)
            .neq('status', 'cancelled');
        
        await _updateUserStats(userId, distance);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error completing trip: $e');
      return false;
    }
  }

  Future<bool> completeBooking(String bookingId, String userId, double distance) async {
    try {
      await _client.from('bookings').update({'status': 'completed'}).eq('id', bookingId);
      await _updateUserStats(userId, distance);
      return true;
    } catch (e) {
      debugPrint('Error completing booking: $e');
      return false;
    }
  }

  Future<void> _updateUserStats(String userId, double distance) async {
    final profile = await _client.from('profiles').select('xp, level, total_distance, treks_completed').eq('id', userId).maybeSingle();
    if (profile == null) return;

    int currentXP = int.tryParse(profile['xp']?.toString() ?? '0') ?? 0;
    double currentDist = double.tryParse((profile['total_distance'] ?? 0).toString()) ?? 0;
    int currentTreks = int.tryParse((profile['treks_completed'] ?? 0).toString()) ?? 0;

    int newXP = currentXP + (distance * 10).toInt();
    int newLevel = (newXP / 1000).floor() + 1;

    await _client.from('profiles').update({
      'xp': newXP,
      'level': newLevel,
      'total_distance': currentDist + distance,
      'treks_completed': currentTreks + 1,
    }).eq('id', userId);
  }

  Future<String?> bookTransport({
    required String transportName,
    required String transportType,
    required String from,
    required String to,
    required DateTime date,
    required double price,
    required String hikerName,
    int? age,
    String? seat,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client.from('transport_bookings').insert({
        'user_id': user.id,
        'transport_name': transportName,
        'transport_type': transportType,
        'origin': from,
        'destination': to,
        'departure_date': date.toIso8601String().split('T')[0],
        'price': price,
        'hiker_name': hikerName,
        'hiker_age': age,
        'seat_preference': seat,
      }).select().single();

      return response['id'];
    } catch (e) {
      debugPrint('Transport Booking Error: $e');
      return null;
    }
  }

  Future<List<dynamic>> fetchTransportBookings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('transport_bookings')
          .select()
          .eq('user_id', user.id)
          .order('departure_date', ascending: true);
      
      return response as List;
    } catch (e) {
      debugPrint('Error fetching transport bookings: $e');
      return [];
    }
  }



  Future<void> updateLastMessage(String roomId, String content) async {
    try {
      await _client.from('trip_groups').update({
        'last_message_content': content,
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('Error updating last message: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String category = 'general',
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'category': category,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }
}
