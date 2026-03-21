import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';
import '../widgets/trek_card.dart';
import '../services/database_service.dart';
import 'profile_screen.dart';
import 'trek_detail_screen.dart';
import 'chat_room_list_screen.dart';
import 'notification_center_screen.dart';
import '../widgets/user_avatar.dart';
import 'admin_dashboard_screen.dart';
import 'admin_panel_screen.dart';
import 'admin_trek_groups_screen.dart';
import 'manage_rentals_screen.dart';
import 'all_treks_screen.dart';
import 'ai_guide_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'admin_chat_list_screen.dart';
import 'trek_training_hub.dart';
import 'admin_support_inquiries_screen.dart';
import 'user_complaints_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_management_hub_screen.dart';
import 'user_gear_rental_screen.dart';
import 'package:intl/intl.dart';
import 'employee_terminal_screen.dart';
import 'trekker_terminal_screen.dart';
import '../widgets/global_unread_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final User? _user = Supabase.instance.client.auth.currentUser;
  
  List<Trek> _allTreks = [];
  List<Trek> _filteredTreks = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _userRole = 'user';
  String? _userName;
  String? _userAvatar;
  Map<String, dynamic>? _activeAlert;

  bool get isAdmin => _userRole == 'admin';

  final List<String> _categories = [
    'All', 
    'Adventure Trek', 
    'Religious Trek', 
    'Yatra', 
    'Weekend Trek', 
    'International Trek'
  ];

  final List<String> _trekkerTips = [
    'Always pace your breathing while ascending—inhale through nose, exhale through mouth.',
    'Keep your rucksack weight evenly distributed; keep heavy items close to your back.',
    'Sip water frequently even if not thirsty—hydration is key to preventing AMS.',
    'Clip your toenails before the trek to avoid pain during steep descents.',
    'Always carry a small personal medical kit with basics like band-aids and antiseptic.',
  ];
  late String _dailyTip;

  @override
  void initState() {
    super.initState();
    _dailyTip = _trekkerTips[DateTime.now().day % _trekkerTips.length];
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadTreks();
    _fetchUserRole();
    _fetchActiveAlert();
  }

  Future<void> _fetchActiveAlert() async {
    try {
      final res = await Supabase.instance.client
          .from('global_alerts')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);
      if (res.isNotEmpty && mounted) {
        setState(() => _activeAlert = res.first);
      }
    } catch (_) {}
  }

  Future<void> _fetchUserRole() async {
    try {
      if (_user != null) {
        final profile = await Supabase.instance.client.from('profiles').select('role, full_name, avatar_url').eq('id', _user!.id).maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _userRole = (profile['role']?.toString().toLowerCase() ?? 'user');
            _userName = profile['full_name'];
            _userAvatar = profile['avatar_url'];
          });
        }
      }
    } catch (_) {}
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedCategory = _categories[_tabController.index];
        _filterTreks();
      });
    }
  }

  Future<void> _loadTreks() async {
    final treks = await _dbService.fetchTreks();
    if (mounted) {
      setState(() {
        _allTreks = treks;
        _filteredTreks = treks;
        _isLoading = false;
      });
    }
  }

  void _filterTreks() {
    setState(() {
      String query = _searchController.text.toLowerCase().trim();
      _filteredTreks = _allTreks.where((trek) {
        bool matchesSearch = query.isEmpty || 
                            trek.title.toLowerCase().contains(query) || 
                            trek.location.toLowerCase().contains(query);
        
        bool matchesCategory = _selectedCategory == 'All' || 
                              trek.category.toLowerCase().contains(_selectedCategory.toLowerCase());
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildExploreScreen(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 50, // Optimized height
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INDIA TREK DEPLOYMENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                    Text('Beautiful India', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _notificationBadge(),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _selectedIndex = 3),
                      child: UserAvatar(
                        imageUrl: _userAvatar,
                        name: _userName ?? _user?.email,
                        radius: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _buildGlobalAnnouncements(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInLeft(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _filterTreks(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search treks, yatras...',
                          icon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDailyInsight(),
                  const SizedBox(height: 20),
                  FadeInUp(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).primaryColor,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: _categories.map((c) => Tab(text: c)).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildTreksList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTreksList() {
    if (_filteredTreks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
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

    // Group by location for better UI and ensure uniqueness to prevent Hero tag collisions
    Map<String, List<Trek>> grouped = {};
    Set<String> processedIds = {};
    
    for (var t in _filteredTreks) {
      if (processedIds.contains(t.id)) continue;
      processedIds.add(t.id);
      
      String region = t.location.split(',').first.trim();
      grouped.putIfAbsent(region, () => []).add(t);
    }

    return Column(
      children: grouped.entries.map((entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (c) => AllTreksScreen(treks: entry.value, title: '${entry.key} Expeditions')
                      )
                    );
                  }, 
                  child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130, // TREK OPTIMIZED: Matches TrekCard (130)
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: entry.value.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: TrekCard(trek: entry.value[index], margin: EdgeInsets.zero),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      )).toList(),
    );
  }

  Widget _buildDailyInsight() {
    return FadeInRight(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade800.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade800, shape: BoxShape.circle),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TREK INTEL', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(_dailyTip, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalAnnouncements() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('global_announcements')
          .stream(primaryKey: ['id'])
          .order('is_urgent', ascending: false)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          if (_activeAlert == null) return const SizedBox.shrink();
          return _legacyAlertWidget();
        }

        final items = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BROADCAST INTEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 2)),
                  GestureDetector(
                    onTap: _showAnnouncementsScreen,
                    child: const Text('VIEW ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ],
              ),
            ),
            Container(
              height: 120,
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: PageView.builder(
                itemCount: items.length > 5 ? 5 : items.length,
                itemBuilder: (context, index) {
                  final a = items[index];
                  return FadeInRight(child: _announcementTile(a));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _announcementTile(Map<String, dynamic> a) {
    final date = DateTime.parse(a['created_at']).toLocal();
    final timeStr = DateFormat('MMM dd | HH:mm').format(date);
    final senderName = a['sender_name'] ?? 'HQ COMMAND';

    final bool isUrgent = a['is_urgent'] ?? false;
    return GestureDetector(
      onTap: () => _showFullAnnouncement(a),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent 
              ? [const Color(0xFF991B1B), const Color(0xFFDC2626)] 
              : [Colors.blue.shade900, Colors.blue.shade700]
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: (isUrgent ? Colors.red : Colors.blue).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(isUrgent ? Icons.warning_amber_rounded : Icons.campaign, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(senderName.toString().toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1.5)),
                      Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 8)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a['content'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullAnnouncement(Map<String, dynamic> a) {
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
                const Icon(Icons.campaign, color: Colors.blueAccent),
                const SizedBox(width: 12),
                const Text('BROADCAST INTEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: FadeInDown(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orange, Colors.redAccent]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(_activeAlert!['message'], style: const TextStyle(color: Colors.white, fontSize: 12))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => setState(() => _activeAlert = null)),
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
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('TREK BROADCASTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
            backgroundColor: Colors.black,
            elevation: 0,
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('global_announcements').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty) return _buildEmptyState();

              return ListView.builder(
                padding: const EdgeInsets.all(25),
                itemCount: items.length,
                itemBuilder: (context, i) {
                   final a = items[i];
                   final date = DateTime.parse(a['created_at']).toLocal();
                   final bool isUrgent = a['is_urgent'] ?? false;
                   final isDark = Theme.of(context).brightness == Brightness.dark;

                   return FadeInUp(
                     delay: Duration(milliseconds: i * 50),
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 20),
                       decoration: BoxDecoration(
                         color: isDark ? const Color(0xFF1E293B) : Colors.white,
                         borderRadius: BorderRadius.circular(25),
                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 10))],
                         border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.grey.shade100)),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                             decoration: BoxDecoration(
                               color: isUrgent ? Colors.redAccent : (isDark ? Colors.white10 : Colors.grey.shade50),
                               borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Row(
                                   children: [
                                     Icon(isUrgent ? Icons.warning_amber_rounded : Icons.info_outline, color: isUrgent ? Colors.white : Colors.blueAccent, size: 14),
                                     const SizedBox(width: 8),
                                     Text(isUrgent ? 'URGENT PRIORITY' : 'OFFICIAL INTEL', style: TextStyle(color: isUrgent ? Colors.white : Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                   ],
                                 ),
                                 Text(DateFormat('MMM dd, HH:mm').format(date), style: TextStyle(color: isUrgent ? Colors.white70 : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                               ],
                             ),
                           ),
                           Padding(
                             padding: const EdgeInsets.all(20),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(a['title'] ?? 'Announcement', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(a['content'], style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.5)),
                               ],
                             ),
                           ),
                         ],
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
    // Determine page set based on role
    final List<Widget> pages;
    final List<BottomNavigationBarItem> navItems;

    if (_userRole == 'admin') {
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const AdminPanelScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(true), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Admin HQ'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    } else if (_userRole == 'guide' || _userRole == 'staff') {
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const EmployeeTerminalScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(false), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.terminal_outlined), label: 'Terminal'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    } else {
      // Default User
      pages = [
        _buildExploreScreen(context),
        const ChatRoomListScreen(),
        const TrekkerTerminalScreen(),
        ProfileScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: _buildChatIcon(false), label: 'Chats'),
        const BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), label: 'Terminal'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
      ];
    }

    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        heroTag: 'support_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AIGuideScreen())),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.support_agent, color: Colors.white),
      ) : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          selectedItemColor: Theme.of(context).primaryColor,
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
          width: 200, // Wider card for more info
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                                leading: UserAvatar(imageUrl: u['avatar_url'], name: u['full_name'], radius: 18),
                                title: Text(u['full_name'] ?? 'Tracker'),
                                subtitle: Text(u['role'] ?? 'user'),
                                trailing: PopupMenuButton<String>(
                                  initialValue: u['role'],
                                  onSelected: (newRole) async {
                                    try {
                                      await Supabase.instance.client.from('profiles').update({'role': newRole}).eq('id', u['id']);
                                      setSheetState(() => u['role'] = newRole);
                                      // Optionally refresh the main screen's data if needed
                                      // fetchData(); // Assuming fetchData is accessible or passed
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'user', child: Text('User')),
                                    const PopupMenuItem(value: 'guide', child: Text('Expedition Guide')),
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

  Widget _notificationBadge() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final count = all.where((n) => n['is_read'] == false).length;
        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.blueAccent),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => NotificationCenterScreen(role: _userRole))),
        );
      },
    );
  }
}
