import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';
import 'supabase_service.dart';

class DatabaseService {
  final _client = SupabaseService().client;

  Future<List<Trek>> fetchTreks() async {
    try {
      final response = await _client.from('treks').select();
      return (response as List).map((e) => Trek.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching treks: $e');
      return []; 
    }
  }

  Future<List<Gear>> fetchGears() async {
    try {
      final response = await _client.from('gears').select();
      print('Fetched ${response.length} gears');
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
    required DateTime trekDate,
    required double trekPrice,
    required double pickupPrice,
    required String pickupLocation,
    required double totalPrice,
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
        'payment_status': 'Paid', // Assuming UPI/Success for demo
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

      // 4. Send Welcome Message to Chat Room
      await _client.from('messages').insert({
        'room_id': groupId,
        'sender_id': user.id,
        'content': 'Hello everyone! I just joined the ${trekDate.day}/${trekDate.month} trek.',
        'is_group_chat': true
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

  Future<void> removeFromGroup(String bookingId) async {
    try {
      // In this app, removing from group is essentially canceling the booking or setting group_id to null
      await _client.from('bookings').update({'group_id': null}).eq('id', bookingId);
    } catch (e) {
      print('Error removing member: $e');
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
      return response as List<Map<String, dynamic>>;
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
      return response as List<Map<String, dynamic>>;
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
      final profile = await _client.from('profiles').select('xp').eq('id', user.id).single();
      final currentXp = profile['xp'] as int? ?? 0;
      await _client.from('profiles').update({'xp': currentXp + amount}).eq('id', user.id);
    } catch (e) {
      print('Error updating XP: $e');
    }
  }
}
