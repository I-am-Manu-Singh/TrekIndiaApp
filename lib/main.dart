import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.initialize();
  
  final isDark = await PreferencesService().getTheme();
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const TrekBookingApp());
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class TrekBookingApp extends StatelessWidget {
  const TrekBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return OverlaySupport.global(
          child: MaterialApp(
            title: 'Trek India',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF2E7D32),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
                secondary: const Color(0xFFFFC107),
              ),
              textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF43A047),
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark,
                seedColor: const Color(0xFF43A047),
                secondary: const Color(0xFFFFD54F),
              ),
              textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
              useMaterial3: true,
            ),
            home: const AuthGuard(),
          ),
        );
      },
    );
  }
}

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});
  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data!.session;
        if (session != null) {
          NotificationService.listenToMessages();
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
