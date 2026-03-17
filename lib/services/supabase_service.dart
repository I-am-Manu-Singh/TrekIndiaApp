import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://xtbrnguknecntvaxtasm.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_AMnLvFmJ9T3OT86Od4p-iw_2m227znW';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  final _supabase = Supabase.instance.client;

  SupabaseClient get client => _supabase;
}
