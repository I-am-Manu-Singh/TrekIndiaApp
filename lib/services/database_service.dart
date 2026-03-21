import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';
import 'supabase_service.dart';

class DatabaseService {
  final _client = SupabaseService().client;

  Future<List<Trek>> fetchTreks() async {
    try {
      // High-Fidelity Trek Fetch: Includes all associated mission packages
      final response = await _client.from('treks').select('*, trek_packages(*)');
      return (response as List).map((e) => Trek.fromJson(e)).toList();
    } catch (e) {
      debugPrint('SITUATION ADVISORY: Primary Intelligence Hub timed out or schema mismatch. Error: $e');
      try {
        // Fallback Sector: Basic mission info if packages fail due to schema sync or relationship errors
        final response = await _client.from('treks').select('*');
        return (response as List).map((e) {
          // Manually add empty packages to satisfy model if select(*) didn't include them
          final data = Map<String, dynamic>.from(e);
          if (!data.containsKey('trek_packages')) data['trek_packages'] = [];
          return Trek.fromJson(data);
        }).toList();
      } catch (e2) {
        debugPrint('TOTAL SECTOR BLACKOUT: All mission data retrieval paths failed. $e2');
        return [];
      }
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

  Future<String?> bookTrek({
    required String trekId,
    required String trekTitle,
    required String fullName,
    required DateTime trekDate,
    required double trekPrice,
    required double pickupPrice,
    required String pickupLocation,
    required double totalPrice,
    // required User user,
    List<Map<String, dynamic>> addons = const []
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      // 1. Find or Create Group for this date
      final dateStr = trekDate.toIso8601String().split('T')[0];
      final groups = await _client.from('trek_groups')
          .select('id')
          .eq('trek_id', trekId)
          .eq('departure_date', dateStr);
      
      String? groupId;
      if ((groups as List).isNotEmpty) {
        groupId = groups[0]['id'];
      } else {
        final groupResponse = await _client.from('trek_groups').insert({
          'trek_id': trekId,
          'departure_date': dateStr,
          'group_name': '$trekTitle - $dateStr',
        }).select().single();
        groupId = groupResponse['id'];
      }

      // 2. Create Booking
      final bookingResponse = await _client.from('bookings').insert({
        'user_id': user.id,
        'trek_id': trekId,
        'group_id': groupId,
        'travelers': 1,
        'trek_date': dateStr,
        'pickup_location': pickupLocation,
        'trek_price': trekPrice,
        'pickup_price': pickupPrice,
        'total_price': totalPrice,
        'payment_status': 'Paid',
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

      // 4. Send Welcome Message
    await _client.from('messages').insert({
      'room_id': groupId,
      'sender_id': user.id,
      'content': "Hello everyone, I'm $fullName! I just joined the ${trekDate.day}/${trekDate.month} trek.",
      'is_group_chat': true,
    });

      return groupId;
    } catch (e) {
      print('Error booking trek: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('bookings')
          .select('id, user_id, is_leader, profiles!inner(full_name, avatar_url, role)')
          .eq('group_id', groupId);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Error fetching members: $e');
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
          .select('*, profiles(full_name, avatar_url)')
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
      print('SITUATION ADVISORY: Achievement sync failed. Error: $e');
    }
  }

  Future<void> completeTrek({required String userId, required String trekId, double distance = 10.0}) async {
    try {
      // 1. Update Booking Status
      await _client.from('bookings').update({'status': 'Completed'}).eq('user_id', userId).eq('trek_id', trekId);

      // 2. Fetch Profile to update stats
      final profile = await _client.from('profiles').select('xp, level, total_distance, trek_count').eq('id', userId).maybeSingle();
      if (profile == null) return;

      int currentXP = int.tryParse(profile['xp']?.toString() ?? '0') ?? 0;
      double currentDist = double.tryParse((profile['total_distance'] ?? 0).toString()) ?? 0;
      int currentTreks = int.tryParse((profile['trek_count'] ?? 0).toString()) ?? 0;

      int newXP = currentXP + 500; // Large reward for trek completion
      double newDist = currentDist + distance;
      int newTreks = currentTreks + 1;
      int newLevel = (newXP / 1000).floor() + 1;

      // 3. Update Profile
      await _client.from('profiles').update({
        'xp': newXP,
        'level': newLevel,
        'total_distance': newDist,
        'total_treks': newTreks, // Ensure this matches UI field name
        'trek_count': newTreks,  // Compatibility fallback
      }).eq('id', userId);

      // 4. Log Achievement
      await _client.from('achievement_unlocks').insert({
        'user_id': userId,
        'achievement_type': 'Trek-Completion',
        'data': {'trek_id': trekId, 'distance': distance}
      });
    } catch (e) {
      print('Error completing trek: $e');
    }
  }
}
