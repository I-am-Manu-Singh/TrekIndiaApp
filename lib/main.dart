import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/admin_trek_groups_screen.dart';
import 'screens/admin_support_inquiries_screen.dart';
import 'screens/admin_bookings_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_rental_tracking_screen.dart';
import 'screens/employee_bookings_screen.dart';
import 'screens/employee_terminal_screen.dart';
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
import 'screens/trek_training_hub.dart';
import 'screens/admin_management_hub_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/app_info_screen.dart';
import 'screens/admin_rental_inventory_screen.dart';
import 'screens/admin_complaints_screen.dart';
import 'screens/employee_tasks_screen.dart';
import 'screens/employee_salary_breakup_screen.dart';

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
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              primaryColor: const Color(0xFF2E7D32),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
                secondary: const Color(0xFFFFC107),
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                iconTheme: IconThemeData(color: Colors.white),
              ),
              textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              primaryColor: const Color(0xFF43A047),
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark,
                seedColor: const Color(0xFF43A047),
                secondary: const Color(0xFFFFD54F),
                surface: const Color(0xFF1E293B),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                iconTheme: IconThemeData(color: Colors.white),
              ),
              textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
              useMaterial3: true,
            ),
            home: const AuthGuard(),
            routes: {
              '/admin': (context) => const AdminPanelScreen(),
              '/admin_panel': (context) => const AdminPanelScreen(),
              '/admin_trek_groups': (context) => const AdminTrekGroupsScreen(),
              '/admin_broadcast': (context) => const AdminBroadcastScreen(),
              '/admin_enquiries': (context) => const AdminSupportInquiriesScreen(),
              '/admin_bookings': (context) => const AdminBookingsScreen(),
              '/admin_dashboard': (context) => const AdminDashboardScreen(),
              '/admin_rentals': (context) => const AdminRentalTrackingScreen(),
              '/employee_terminal': (context) => const EmployeeTerminalScreen(),
              '/employee_wallet': (context) => const EmployeeWalletScreen(),
              '/chat_rooms': (context) => const ChatRoomListScreen(),
              '/my_trips': (context) => const MyTripsScreen(),
              '/blogs': (context) => const BlogsScreen(),
              '/payment_ledger': (context) => const PaymentLedgerScreen(),
              '/user_rentals': (context) => const UserGearRentalScreen(),
              '/user_complaints': (context) => const UserComplaintsScreen(),
              '/edit_profile': (context) => const EditProfileScreen(),
              '/tactical_dossier': (context) => const EditProfileScreen(),
              '/notifications': (context) => const NotificationCenterScreen(),
              '/training_hub': (context) => const TrekTrainingHub(),
              '/admin_management': (context) => const AdminManagementHubScreen(),
              '/admin_staff': (context) => const AdminManagementHubScreen(),
              '/admin_complaints': (context) => const AdminComplaintsScreen(),
              '/hq_finance': (context) => const AdminWalletScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/app_info': (context) => const AppInfoScreen(),
              '/employee_tasks': (context) => const EmployeeTasksScreen(),
              '/employee_squads': (context) => const EmployeeBookingsScreen(),
              '/salary_breakup': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return EmployeeSalaryBreakupScreen(profileOverride: args);
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
