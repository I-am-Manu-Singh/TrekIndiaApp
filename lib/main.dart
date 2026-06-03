import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/admin_trip_groups_screen.dart';
import 'screens/admin_support_inquiries_screen.dart';
import 'screens/admin_bookings_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_rental_tracking_screen.dart';
import 'screens/employee_bookings_screen.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/employee_wallet_screen.dart';
import 'screens/admin_broadcast_screen.dart';
import 'screens/admin_wallet_screen.dart';
import 'screens/chat_room_list_screen.dart';
import 'screens/my_trips_screen.dart';
import 'screens/blogs_screen.dart';
import 'screens/payment_ledger_screen.dart';
import 'screens/user_gear_rental_screen.dart';
import 'screens/user_complaints_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/notification_center_screen.dart';
import 'screens/trip_training_hub.dart';
import 'screens/admin_management_hub_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/app_info_screen.dart';
import 'screens/admin_rental_inventory_screen.dart';
import 'screens/admin_complaints_screen.dart';
import 'screens/employee_salary_breakup_screen.dart';
import 'screens/admin_tasks_screen.dart';
import 'screens/employee_tasks_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.initialize();
  
  final isDark = await PreferencesService().getTheme();
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const TripBookingApp());
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class TripBookingApp extends StatelessWidget {
  const TripBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return OverlaySupport.global(
          child: MaterialApp(
            title: 'trekwithmussafirr',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              primaryColor: const Color(0xFFD32F2F), // Red
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD32F2F), // Red
                primary: const Color(0xFFD32F2F),
                secondary: const Color(0xFFB71C1C),
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFD32F2F), // Red AppBar
                foregroundColor: Colors.white, // White text/icons
                elevation: 0,
                centerTitle: true,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              primaryColor: const Color(0xFFD32F2F), // Red
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark,
                seedColor: const Color(0xFFD32F2F), // Red
                primary: const Color(0xFFD32F2F),
                secondary: const Color(0xFFB71C1C),
                surface: const Color(0xFF1E293B),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFD32F2F), // Red AppBar
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
              useMaterial3: true,
            ),
            home: const AuthGuard(),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/admin': (context) => const AdminPanelScreen(),
              '/admin_panel': (context) => const AdminPanelScreen(),
              '/admin_trip_groups': (context) => const AdminTripGroupsScreen(),
              '/admin_broadcast': (context) => const AdminBroadcastScreen(),
              '/admin_enquiries': (context) => const AdminSupportInquiriesScreen(),
              '/admin_bookings': (context) => const AdminBookingsScreen(),
              '/admin_dashboard': (context) => const AdminDashboardScreen(),
              '/admin_rentals': (context) => const AdminRentalTrackingScreen(),
              '/employee_dashboard': (context) => const EmployeeDashboardScreen(),
              '/employee_wallet': (context) => const EmployeeWalletScreen(),
              '/chat_rooms': (context) => const ChatRoomListScreen(),
              '/my_trips': (context) => const MyTripsScreen(),
              '/blogs': (context) => const BlogsScreen(),
              '/payment_ledger': (context) => const PaymentLedgerScreen(),
              '/user_rentals': (context) => const UserGearRentalScreen(),
              '/user_complaints': (context) => const UserComplaintsScreen(),
              '/edit_profile': (context) => const EditProfileScreen(),
              '/travel_documents': (context) => const EditProfileScreen(),
              '/notifications': (context) => const NotificationCenterScreen(),
              '/training_hub': (context) => const TripTrainingHub(),
              '/admin_management': (context) => const AdminManagementHubScreen(),
              '/admin_finance': (context) => const AdminWalletScreen(),
              '/admin_employees': (context) => const AdminManagementHubScreen(),
              '/admin_support_inquiries': (context) => const AdminSupportInquiriesScreen(),
              '/admin_complaints': (context) => const AdminComplaintsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/app_info': (context) => const AppInfoScreen(),
              '/employee_tasks': (context) => const EmployeeTasksScreen(),
              '/employee_groups': (context) => const EmployeeBookingsScreen(),
              '/salary_breakup': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return EmployeeSalaryBreakupScreen(profileOverride: args);
              },
              '/admin_tasks': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as String?;
                return AdminTasksScreen(initialStaffId: args);
              },
            },
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
  Session? _session;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _initialized = true;
    
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _session = data.session;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session != null) {
      NotificationService.listenToMessages();
      NotificationService.listenToBookingChanges();
      return const HomeScreen();
    }
    if (kIsWeb) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
