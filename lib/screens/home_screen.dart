import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:collection/collection.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../models/trip.dart';
import '../widgets/unified_trip_card.dart';
import '../services/database_service.dart';
import 'profile_screen.dart';
import 'trip_detail_screen.dart';
import 'chat_room_list_screen.dart';
import 'notification_center_screen.dart';
import '../widgets/user_avatar.dart';
import 'admin_dashboard_screen.dart';
import 'admin_panel_screen.dart';
import 'admin_trip_groups_screen.dart';
import 'all_trips_screen.dart';
import 'ai_guide_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'transport_booking_screen.dart';
import 'admin_chat_list_screen.dart';
import 'trip_training_hub.dart';
import 'admin_support_inquiries_screen.dart';
import 'user_complaints_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_management_hub_screen.dart';
import 'user_gear_rental_screen.dart';
import 'package:intl/intl.dart';
import 'employee_dashboard_screen.dart';
import 'trip_dashboard_screen.dart';
import '../widgets/global_unread_badge.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/refund_policy_screen.dart';
import 'legal/safety_protocols_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'login_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  User? get _user => Supabase.instance.client.auth.currentUser;
  
  List<Trip> _allTrips = [];
  List<Trip> _filteredTrips = [];
  bool _isLoading = true;
  bool _isTripsLoading = true;
  String _selectedCategory = 'All';
  String _userRole = 'user';
  String? _userName;
  String? _userAvatar;
  Map<String, dynamic>? _activeAlert;
  int _lastSelectedIndex = 0;
  int _currentAnnouncementPage = 0;
  final PageController _announcementController = PageController();
  bool get isAdmin => _userRole == 'admin';
  List<TripCategory> _availableCategories = [];
  List<String> _categoryNames = ['All'];
  bool _isVerified = false;

  StreamSubscription? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isOffline = false;

  final String _dailyTip = "Pro Tip: Layering is key! Keep a moisture-wicking base layer for high-altitude trips.";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryNames.length, vsync: this);
    _handleInitialLoad();
    _checkConnectivity();
    _fetchActiveAlert();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        if (data.session == null) {
          setState(() {
            _selectedIndex = 0;
            _userRole = 'user';
            _userName = null;
            _userAvatar = null;
            _isVerified = false;
          });
        }
        _handleInitialLoad();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = result == ConnectivityResult.none);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) setState(() => _isOffline = result == ConnectivityResult.none);
    });
  }

  Future<void> _handleInitialLoad() async {
    try {
      await Future.wait([
        _fetchCategories(),
        _fetchUserRole(),
      ]);
      _loadTrips();
    } catch (e) {
      debugPrint('CRITICAL LOAD ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await _dbService.fetchCategories();
      if (mounted) {
        final newNames = ['All', ...cats.map((c) => c.name)];
        
        // Create new controller first to avoid race condition
        final newController = TabController(length: newNames.length, vsync: this);
        newController.addListener(_handleTabSelection);
        
        setState(() {
          _availableCategories = cats;
          _categoryNames = newNames;
          final oldController = _tabController;
          _tabController = newController;
          // Safely dispose old controller after swap
          oldController.dispose();
          _lastSelectedIndex = 0;
          _selectedCategory = 'All';
        });
        
        _filterTrips();
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  void _handleTabSelection() {
    if (!mounted || _tabController.indexIsChanging) return;
    if (_tabController.index < _categoryNames.length) {
      setState(() {
        _lastSelectedIndex = _tabController.index;
        _selectedCategory = _categoryNames[_tabController.index];
        _filterTrips();
      });
    }
  }

  Future<void> _loadTrips() async {
    if (mounted) setState(() => _isTripsLoading = true);
    try {
      final trips = await _dbService.fetchTrips().timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _allTrips = trips;
          _filteredTrips = trips;
          _isTripsLoading = false;
          _filterTrips();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isTripsLoading = false);
    }
  }

  void _filterTrips() {
    setState(() {
      String query = _searchController.text.toLowerCase().trim();
      List<Trip> baseList;
      
      if (_selectedCategory == 'All') {
        baseList = _allTrips;
      } else {
        baseList = _allTrips.where((t) {
          final tripCat = (t.category ?? '').trim().toLowerCase();
          final targetCat = _selectedCategory.trim().toLowerCase();
          // Precise match or loose contains
          return tripCat == targetCat || targetCat.contains(tripCat) || tripCat.contains(targetCat);
        }).toList();
        debugPrint('FILTERING: Selected=$_selectedCategory, ResultCount=${baseList.length}');
      }

      _filteredTrips = baseList.where((trip) {
        return query.isEmpty || 
               trip.title.toLowerCase().contains(query) || 
               trip.location.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    _announcementController.dispose();
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _userName = null;
          _userAvatar = null;
          _isVerified = false;
        });
      }
      return;
    }
    try {
      final res = await Supabase.instance.client.from('profiles').select('role, full_name, avatar_url, aadhar_url, medical_certificate_url').eq('id', user.id).maybeSingle();
      
      if (mounted) {
        String? finalName = res?['full_name'];
        if (finalName == null || finalName.trim().isEmpty || finalName == 'Explorer') {
          finalName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
          if (finalName == null || finalName.trim().isEmpty) {
             finalName = user.email?.split('@')[0] ?? 'Explorer';
             // Silent Repair: Save email prefix as name to DB
             Supabase.instance.client.from('profiles').update({'full_name': finalName}).eq('id', user.id).then((_) {});
          }
        }

        setState(() {
          _userRole = res?['role'] ?? 'user';
          _userName = finalName;
          _userAvatar = res?['avatar_url'];

          if (_userAvatar == null || _userAvatar!.isEmpty) {
            _userAvatar = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'] ?? '';
          }
          _isVerified = res?['aadhar_url'] != null || res?['medical_certificate_url'] != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  Future<void> _fetchActiveAlert() async {
    try {
      final res = await Supabase.instance.client.from('app_alerts').select().eq('is_active', true).maybeSingle();
      if (mounted && res != null) {
        setState(() => _activeAlert = res);
      }
    } catch (_) {}
  }

  Widget _buildHomeShimmer() {
    return GlassShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const ShimmerBlock(width: double.infinity, height: 180, margin: EdgeInsets.all(20), borderRadius: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (i) => const ShimmerBlock(width: 70, height: 70, borderRadius: 15)),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(4, (i) => const ShimmerBlock(width: 80, height: 35, margin: EdgeInsets.only(right: 12), borderRadius: 10)),
              ),
            ),
            const SizedBox(height: 30),
            ...List.generate(2, (i) => const ShimmerBlock(width: double.infinity, height: 280, margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10), borderRadius: 24)),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({required EdgeInsets margin, required double height, required double radius}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: margin,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('trekwithmussafirr', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        centerTitle: false,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Theme.of(context).primaryColor),
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: _buildAppBarActions(context),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (_user == null) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
            icon: const Icon(Icons.login, color: Colors.white, size: 18),
            label: const Text('LOGIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ];
    }
    return [
      _glassHeaderAction(_notificationBadge()),
      Padding(
        padding: const EdgeInsets.only(right: 16, left: 8),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen())),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                ),
                child: UserAvatar(
                  imageUrl: _userAvatar, 
                  name: _userName, 
                  width: 44, 
                  height: 44, 
                  borderRadius: BorderRadius.circular(14)
                ),
              ),
              if (_isVerified)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(Icons.verified, color: Colors.white, size: 6),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _glassHeaderAction(Widget child, {EdgeInsets padding = const EdgeInsets.only(right: 12)}) {
    return Padding(
      padding: padding,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _notificationBadge({Color? iconColor}) {
    return StreamBuilder<int>(
      initialData: 0,
      stream: Stream.periodic(const Duration(seconds: 15)).asyncMap((_) async {
        final res = await Supabase.instance.client.from('notifications').select('id').eq('user_id', _user?.id ?? '').eq('is_read', false);
        return (res as List).length;
      }),
      builder: (context, snapshot) {
        int count = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.notifications_none_rounded, color: iconColor ?? Colors.white, size: 32),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationCenterScreen())),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text('$count', style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExploreScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Error Logging for Null Check issues
    final oldErrorBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('HOME SCREEN BUILD ERROR: ${details.exception}');
      return Container(
        color: Colors.red[900],
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Build Error: ${details.exception}\nCheck logs for details.',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      );
    };

    if (_tabController == null || _categoryNames.isEmpty) {
       return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWebHeader(context),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kIsWeb) _buildWebSearchBar(context),
                  _buildCombinedInsights(),
                  _buildTransportHub(),
                  // CATEGORIES MOVED ABOVE CURATED COLLECTIONS
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      key: ValueKey(_categoryNames.join(',')),
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? Colors.white38 : Colors.grey,
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFD32F2F),
                        boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(4),
                      tabs: _categoryNames.map((c) => Tab(text: (c ?? 'TRIP').toUpperCase())).toList(),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        () {
                          final query = _searchController.text.toLowerCase().trim();
                          final specialTrips = _allTrips.where((t) {
                            final cat = _availableCategories.firstWhere(
                              (c) => c.name == t.category, 
                              orElse: () => TripCategory(id: 'default', name: '', isSpecial: false)
                            );
                            bool matchesCat = _selectedCategory == 'All' || 
                                             t.category?.toLowerCase() == _selectedCategory.toLowerCase() ||
                                             _selectedCategory.toLowerCase().contains(t.category?.toLowerCase() ?? '');
                            bool matchesQuery = query.isEmpty ||
                                                t.title.toLowerCase().contains(query) ||
                                                (t.location ?? '').toLowerCase().contains(query);
                            return cat.isSpecial && matchesCat && matchesQuery;
                          }).toList();

                          if (specialTrips.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader('Curated Collections', onSeeAll: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AllTripsScreen(
                                      initialCategory: 'Special',
                                      allTrips: _allTrips,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              _buildHorizontalTripList(specialTrips, heroPrefix: 'special'),
                              const SizedBox(height: 8),
                            ],
                          );
                        }(),
                      ],
                    ),
                  ),
                  _buildPackagesSection(), // 👈 ADDED PACKAGES SECTION
                  _buildTripsList(),
                ],
              ),
            ),
          ),
          _buildWebFooter(context),
          if (!kIsWeb) const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPackagesSection() {
    final query = _searchController.text.toLowerCase().trim();
    final packages = _allTrips.where((t) {
      final cat = t.category?.toLowerCase() ?? '';
      bool isPkg = cat == 'vacation' || cat == 'package' || cat == 'packages';
      bool matchesCat = _selectedCategory == 'All' || 
                       cat == _selectedCategory.toLowerCase() ||
                       _selectedCategory.toLowerCase().contains(cat);
      bool matchesQuery = query.isEmpty ||
                          t.title.toLowerCase().contains(query) ||
                          (t.location ?? '').toLowerCase().contains(query);
      return isPkg && matchesCat && matchesQuery;
    }).toList();

    if (packages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Exclusive Packages', onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllTripsScreen(
                initialCategory: 'Packages',
                allTrips: _allTrips,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        _buildHorizontalTripList(packages, heroPrefix: 'pkg'),
        const SizedBox(height: 24),
      ],
    );
  }

  // Widget _buildDailyInsightCard() {
  //   final isDark = Theme.of(context).brightness == Brightness.dark;
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).primaryColor),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Text(
  //             _dailyTip,
  //             style: TextStyle(
  //               color: isDark ? Colors.white70 : Colors.black87,
  //               fontSize: 10,
  //               fontWeight: FontWeight.w600,
  //               height: 1.3,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildDailyInsightCard() {
  //   final isDark = Theme.of(context).brightness == Brightness.dark;
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).primaryColor),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Text(
  //             _dailyTip,
  //             style: TextStyle(
  //               color: isDark ? Colors.white70 : Colors.black87,
  //               fontSize: 10,
  //               fontWeight: FontWeight.w600,
  //               height: 1.3,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildDailyInsightCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dailyTip,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedInsights() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          _buildDailyInsightCard(),
          const SizedBox(height: 16),
          _buildAnnouncementsSlider(),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSlider() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('global_announcements')
          .stream(primaryKey: ['id'])
          .order('is_urgent', ascending: false)
          .order('created_at', ascending: false)
          .limit(5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final items = snapshot.data!;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 12, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(2))),
                    Text(('LATEST UPDATES' ?? 'ADVENTURE').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F), letterSpacing: 1.5)),
                  ],
                ),
                GestureDetector(
                  onTap: _showAnnouncementsScreen,
                  child: const Text('VIEW ALL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: PageView.builder(
                controller: _announcementController,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _currentAnnouncementPage = i),
                itemBuilder: (context, index) {
                  final a = items[index];
                  final isUrgent = a['is_urgent'] == true;
                  final color = isUrgent ? Colors.redAccent : Colors.blueAccent;

                  return GestureDetector(
                    onTap: () => _showFullAnnouncement(a),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(isUrgent ? Icons.warning_amber_rounded : Icons.campaign_outlined, color: color, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(a['title'] ?? 'IMPORTANT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: color)),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    a['content'] ?? '', 
                                    maxLines: 3, 
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.2)
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentAnnouncementPage == i ? const Color(0xFFD32F2F) : Colors.grey.withOpacity(0.3),
                ),
              )),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          TextButton(
            onPressed: onSeeAll ?? () {},
            child: const Text('VIEW ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTripList(List<Trip> trips, {String heroPrefix = 'horiz'}) {
    final bool isSpecialRow = trips.any((t) {
      final cat = _availableCategories.firstWhereOrNull((c) => c.name == t.category);
      return cat?.isSpecial ?? false;
    });
    
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final t = trips[index];
          final catMeta = _availableCategories.where((c) => c.name == t.category).firstOrNull;
          final isSpecial = catMeta?.isSpecial ?? false;
          
          return UnifiedTripCard(
            trip: t, 
            categoryMeta: catMeta, 
            margin: const EdgeInsets.only(right: 16),
            heroTag: '${heroPrefix}_${t.id}',
            onRefresh: _loadTrips,
          );
        },
      ),
    );
  }

Widget _buildTransportHub() {
  final isSmallScreen = MediaQuery.of(context).size.width < 400;

  return Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transportation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            isSmallScreen
                ? Column(
                    children: [
                      _busCard(),
                      const SizedBox(height: 16),
                      _trainCard(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _busCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _trainCard()),
                    ],
                  ),
          ],
        ),
      ),
    ),
  );
}
Widget _busCard() {
  return _transportCard(
    'Book Bus Services',
    Icons.directions_bus_filled,
    const Color(0xFFD32F2F),
    () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TransportBookingScreen(initialMode: 'bus'),
      ),
    ),
  );
}

Widget _trainCard() {
  return _transportCard(
    'Book Train Services',
    Icons.train,
    const Color(0xFF1565C0),
    () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TransportBookingScreen(initialMode: 'train'),
      ),
    ),
  );
}

Widget _transportCard(
  String title,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildTripsList() {
    if (_isTripsLoading) {
      return Column(
        children: List.generate(3, (i) => Column(
          children: [
            _shimmerBox(margin: const EdgeInsets.symmetric(horizontal: 20), height: 400, radius: 24),
            const SizedBox(height: 16),
          ],
        )),
      );
    }

    if (_filteredTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No results for "$_selectedCategory"', style: const TextStyle(color: Colors.grey, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    Map<String, List<Trip>> grouped = {};
    Set<String> processedIds = {};
    
    for (var t in _filteredTrips) {
      if (processedIds.contains(t.id)) continue;
      processedIds.add(t.id);
      
      String location = t.location ?? 'Global';
      String region = location.isEmpty ? 'Global' : location.split(',').first.trim();
      if (region.isEmpty) region = 'Global';
      
      grouped.putIfAbsent(region, () => []).add(t);
    }

    return Column(
      children: grouped.entries.map((entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (c) => AllTripsScreen(
                          allTrips: entry.value, 
                          initialCategory: entry.key,
                        )
                      )
                    );
                  }, 
                  child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),
          _buildHorizontalTripList(entry.value, heroPrefix: 'group_${entry.key}'),
          const SizedBox(height: 10),
        ],
      )).toList(),
    );
  }


  Widget _announcementTile(Map<String, dynamic> a, int index, int total) {
    final String createdAt = a['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final date = DateTime.parse(createdAt).toLocal();
    final timeStr = DateFormat('MMM dd | HH:mm').format(date);
    final senderName = a['sender_name']?.toString() ?? 'trekwithmussafirr OFFICE';
    final bool isUrgent = a['is_urgent'] == true;
    final String content = a['content']?.toString() ?? 'No details provided.';

    final accentColor = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final lightBg = isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);

    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? 0 : 6,
        right: index == total - 1 ? 0 : 6,
      ),
      child: GestureDetector(
        onTap: () => _showFullAnnouncement(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.25), width: 1.2),
            boxShadow: [
              BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Icon(isUrgent ? Icons.warning_amber_rounded : Icons.campaign, color: accentColor, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 16, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                        Expanded(child: Text(senderName.toUpperCase(), style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5))),
                        Text(timeStr, style: const TextStyle(color: Colors.black45, fontSize: 9)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullAnnouncement(Map<String, dynamic> a) {
  final date = DateTime.parse(a['created_at']).toLocal();
 showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFFD32F2F)),
                const SizedBox(width: 12),
                const Text('LATEST UPDATES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 30),
            Text(a['title'] ?? 'IMPORTANT NOTICE', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(DateFormat('MMMM dd, yyyy | HH:mm').format(DateTime.parse(a['created_at']).toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(a['content'], style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.blueGrey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _legacyAlertWidget() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: FadeInDown(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey,
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _activeAlert?['message'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(width: 6),

            GestureDetector(
              onTap: () => setState(() => _activeAlert = null),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  


void _showAnnouncementsScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF09090B)
            : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'TRIP BROADCASTS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          elevation: 0,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('global_announcements')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data!;
            if (items.isEmpty) return _buildEmptyState();

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                final date =
                    DateTime.parse(a['created_at']).toLocal();
                final bool isUrgent = a['is_urgent'] ?? false;
                final isDark =
                    Theme.of(context).brightness == Brightness.dark;

                return GestureDetector(
                  onTap: () => _showFullAnnouncement(a),
                  child: FadeInUp(
                    delay: Duration(milliseconds: i * 40),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF18181B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isUrgent
                              ? Colors.redAccent.withOpacity(0.25)
                              : (isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200),
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isUrgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                              size: 18,
                              color: isUrgent
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isUrgent
                                            ? 'URGENT'
                                            : 'UPDATE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isUrgent
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('MMM dd, HH:mm')
                                            .format(date),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    a['title'] ?? 'Announcement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    a['content'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.campaign_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No broadcasts in theoretical airwaves.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Error Logger
    ErrorWidget.builder = (details) {
      debugPrint('HOME_UI_ERROR: ${details.exception}');
      return Center(child: Text('Error: ${details.exception}', style: TextStyle(color: Colors.red)));
    };

    final List<Widget> pages;
    final List<BottomNavigationBarItem> navItems;
    final String title;

    if (_userRole == 'admin') {
      title = 'ADMIN CENTER';
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const AdminPanelScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(true), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Admin'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    } else if (_userRole == 'staff' || _userRole == 'employee' || _userRole == 'guide') {
      title = 'STAFF PORTAL';
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const EmployeeDashboardScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(false), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    } else {
      title = 'trekwithmussafirr';
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const TripDashboardScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(false), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    }

    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    final String appBarTitle;
    if (_user == null) {
      appBarTitle = 'trekwithmussafirr';
    } else {
      final name = _userName ?? 'Explorer';
      if (_userRole == 'admin') {
        appBarTitle = '${name.toUpperCase()} (ADMIN)';
      } else if (_userRole == 'staff' || _userRole == 'employee' || _userRole == 'guide') {
        appBarTitle = '${name.toUpperCase()} (STAFF)';
      } else {
        appBarTitle = name.toUpperCase();
      }
    }

    return Scaffold(
      appBar: (_selectedIndex == 0 && !kIsWeb) ? AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('trekwithmussafirr', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
            if (_user != null)
              Text(
                appBarTitle,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
              )
            else
              const Text(
                'trekwithmussafirr',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        centerTitle: false,
        actions: _buildAppBarActions(context),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => _filterTrips(),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search your next peak...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, size: 18, color: Color(0xFFD32F2F)),
                ),
              ),
            ),
          ),
        ),
      ) : null,
      floatingActionButton: _selectedIndex == 0
        ? FloatingActionButton.extended(
            heroTag: 'support_fab',
            onPressed: _showEnquiryForm,
            backgroundColor: const Color(0xFFD32F2F),
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            label: const Text('Enquire Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
      body: Column(
        children: [
          if (_isOffline)
            Container(
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  const Text('OFFLINE MODE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _handleInitialLoad(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: Size.zero,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('RECONNECT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading 
              ? _buildHomeShimmer()
              : IndexedStack(
                  index: _selectedIndex,
                  children: pages,
                ),
          ),
        ],
      ),
      bottomNavigationBar: (_user == null || kIsWeb) ? null : Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF18181B) : Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          selectedItemColor: const Color(0xFFD32F2F),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: navItems,
        ),
      ),
    );
  }

  Widget _buildChatIcon(bool isAdmin) {
    return const GlobalUnreadBadge(icon: Icon(Icons.chat_bubble_outline));
  }


  Widget _hubCard(String title, IconData icon, Color color, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInRight(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                title, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeMenuCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInRight(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87
                    )
                  ),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminTile(IconData icon, String title, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setSheetState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('USER MANAGEMENT', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: Supabase.instance.client.from('profiles').select().order('full_name', ascending: true),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No users found.'));
                          }

                          final users = snapshot.data!;
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final u = users[index];
                              return ListTile(
                                leading: UserAvatar(imageUrl: u['avatar_url'], name: u['full_name'], width: 36, height: 36, borderRadius: BorderRadius.circular(8)),
                                title: Text(u['full_name'] ?? 'Tracker'),
                                subtitle: Text(u['role'] ?? 'user'),
                                trailing: PopupMenuButton<String>(
                                  initialValue: u['role'],
                                  onSelected: (newRole) async {
                                    try {
                                      await Supabase.instance.client.from('profiles').update({'role': newRole}).eq('id', u['id']);
                                      setSheetState(() => u['role'] = newRole);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'user', child: Text('User')),
                                    const PopupMenuItem(value: 'staff', child: Text('Staff / Guide')),
                                    const PopupMenuItem(value: 'admin', child: Text('Administrator')),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  Future<void> _launchGoogleForm() async {
    final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSfD_K_7h8YqUqyGvq7fO2Uv0Kz3c6W9v3G7Gg4Y5Q5Q5Q5Q5Q/viewform');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showEnquiryForm() {
    const String formUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSfD_K_7h8YqUqyGvq7fO2Uv0Kz3c6W9v3G7Gg4Y5Q5Q5Q5Q5Q/viewform';
    launchUrl(Uri.parse(formUrl), mode: LaunchMode.externalApplication);
  }


  Widget _buildWebHeader(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final bool isWide = MediaQuery.of(context).size.width > 900;
    if (!isWide) return const SizedBox.shrink();
    
    final String displayTitle;
    if (_user == null) {
      displayTitle = 'trekwithmussafirr';
    } else {
      final name = _userName ?? 'Explorer';
      if (_userRole == 'admin') {
        displayTitle = '${name.toUpperCase()} (ADMIN)';
      } else if (_userRole == 'staff' || _userRole == 'employee' || _userRole == 'guide') {
        displayTitle = '${name.toUpperCase()} (STAFF)';
      } else {
        displayTitle = name.toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF18181B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/images/app_logo.png', width: 40, height: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'trekwithmussafirr',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFFD32F2F)),
                  ),
                  if (_user != null)
                    Text(
                      displayTitle,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                    ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _webNavLink(context, 'Explore', () => setState(() => _selectedIndex = 0), isActive: _selectedIndex == 0),
              if (_user != null) ...[
                _webNavLink(context, 'Chats', () => setState(() => _selectedIndex = 1), isActive: _selectedIndex == 1),
                if (_userRole == 'admin')
                  _webNavLink(context, 'Admin Panel', () => setState(() => _selectedIndex = 2), isActive: _selectedIndex == 2)
                else if (_userRole == 'staff' || _userRole == 'employee' || _userRole == 'guide')
                  _webNavLink(context, 'Dashboard', () => setState(() => _selectedIndex = 2), isActive: _selectedIndex == 2)
                else
                  _webNavLink(context, 'Dashboard', () => setState(() => _selectedIndex = 2), isActive: _selectedIndex == 2),
                
                _webNavLink(context, 'Account', () => setState(() => _selectedIndex = 3), isActive: _selectedIndex == 3),
              ],
              const SizedBox(width: 20),
              if (_user == null)
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                  child: const Text('Login / Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else ...[
                _notificationBadge(iconColor: const Color(0xFFD32F2F)),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Log Out?'),
                        content: const Text('Are you sure you want to end your current session?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await Supabase.instance.client.auth.signOut();
                    }
                  },
                  icon: const Icon(Icons.logout, color: Color(0xFFD32F2F)),
                  tooltip: 'Log Out',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _filterTrips();
                },
                decoration: const InputDecoration(
                  hintText: 'Search treks, package destinations, guides...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webNavLink(BuildContext context, String title, VoidCallback onTap, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD32F2F).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isActive
                  ? const Color(0xFFD32F2F)
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF09090B) : const Color(0xFF18181B),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('trekwithmussafirr', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Text(
                      'Your premier trekking companion in the Himalayas. Discover trails, book expeditions, and explore the unexplored with professional safety guidance.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Policies', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _footerLink(context, 'Privacy Policy', () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PrivacyPolicyScreen()))),
                    _footerLink(context, 'Terms of Service', () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TermsOfServiceScreen()))),
                    _footerLink(context, 'Refund Policy', () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RefundPolicyScreen()))),
                    _footerLink(context, 'Safety Protocols', () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SafetyProtocolsScreen()))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact Us', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Email: info@trekwithmussafirr.com', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Phone: +91 9876543210', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Address: Manali, Himachal Pradesh, India', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10),
          const SizedBox(height: 15),
          Text(
            '© ${DateTime.now().year} trekwithmussafirr. All rights reserved. Managed with pride.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(BuildContext context, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final List<String> categoryNames;
  final Function(int) onTap;
  final Key? key;

  _CategoryHeaderDelegate({
    required this.tabController,
    required this.categoryNames,
    required this.onTap,
    this.key,
  });

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: TabBar(
          key: ValueKey(categoryNames.join(',')),
          controller: tabController,
          onTap: onTap,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white, // 👈 WHITE TEXT ON DARK BG
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: categoryNames.map((c) => Tab(text: (c ?? 'Adventure').toUpperCase())).toList(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.categoryNames.join(',') != categoryNames.join(',') || 
           oldDelegate.tabController != tabController;
  }
}
// END OF HOME SCREEN
