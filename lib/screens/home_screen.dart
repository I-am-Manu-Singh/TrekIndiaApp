import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';
import '../widgets/trek_card.dart';
import '../services/database_service.dart';
import 'profile_screen.dart';
import 'blogs_screen.dart';
import 'trek_detail_screen.dart';
import 'chat_room_list_screen.dart';
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
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();
  
  List<Trek> _allTreks = [];
  List<Trek> _filteredTreks = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _userRole = 'user';
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
        final profile = await Supabase.instance.client.from('profiles').select('role').eq('id', _user!.id).maybeSingle();
        if (profile != null && mounted) {
          setState(() => _userRole = profile['role'] ?? 'user');
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
            expandedHeight: 90, // Increased height to prevent 7px overflow
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
                    const Text('TACTICAL DEPLOYMENT: INDIA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                    Text('Beautiful India', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _buildNotificationIcon(),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.article_outlined, size: 22, color: Colors.blueAccent),
                      tooltip: 'EXPEDITION BLOGS',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen())),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _selectedIndex = 3), // Account is at 3
                      child: UserAvatar(
                        imageUrl: _user?.userMetadata?['avatar_url'],
                        name: _user?.userMetadata?['full_name'] ?? _user?.email,
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
                  const SizedBox(height: 24),
                  _buildDailyInsight(),
                  const SizedBox(height: 30),
                  _buildTrekkerHub(),
                  const SizedBox(height: 30),
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
                  const SizedBox(height: 24),
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
            height: 180, // Strategic height adjustment
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: entry.value.length > 3 ? 4 : entry.value.length,
              itemBuilder: (context, index) {
                if (index == 3) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 30),
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => AllTreksScreen(treks: entry.value, title: '${entry.key} Expeditions')
                            )
                          );
                        },
                        child: const Text('View More'),
                      ),
                    ),
                  );
                }
                return Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  margin: const EdgeInsets.only(right: 16),
                  child: TrekCard(trek: entry.value[index]),
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
                  const Text('TACTICAL INTEL', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          if (_activeAlert == null) return const SizedBox.shrink();
          return _legacyAlertWidget();
        }

        final items = snapshot.data!;
        return Container(
          height: 80,
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: PageView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final a = items[index];
              return _announcementTile(a);
            },
          ),
        );
      },
    );
  }

  Widget _announcementTile(Map<String, dynamic> a) {
    final date = DateTime.parse(a['created_at']).toLocal();
    final timeStr = DateFormat('MMM dd, HH:mm').format(date);
    
    return GestureDetector(
      onTap: () => _showFullAnnouncement(a),
      onLongPress: _showAnnouncementsList,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(a['title'].toString().toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1.5)),
                      Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 8)),
                    ],
                  ),
                  Text(a['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
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

  void _showFullAnnouncement(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(a['content']),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('DISMISS'))],
      ),
    );
  }

  void _showAnnouncementsList() async {
    final res = await Supabase.instance.client.from('global_announcements').select().order('created_at', ascending: false);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('ALL EXPEDITION ANNOUNCEMENTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: res.length,
                itemBuilder: (context, i) {
                  final a = res[i];
                  return ListTile(
                    title: Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(a['created_at']).toLocal())),
                    onTap: () { Navigator.pop(context); _showFullAnnouncement(a); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _userRole == 'admin';

    // Both admin and user get 4 tabs - prevents index mismatch on theme change
    final int maxIndex = 3;
    if (_selectedIndex > maxIndex) _selectedIndex = 0;

    final List<Widget> pages = isAdmin 
      ? [
          _buildExploreScreen(context),
          const ChatRoomListScreen(),
          const AdminPanelScreen(),
          ProfileScreen(key: _profileKey),
        ]
      : [
          _buildExploreScreen(context),
          const ChatRoomListScreen(),
          const BlogsScreen(),
          ProfileScreen(key: _profileKey),
        ];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'support_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AIGuideScreen())),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.support_agent, color: Colors.white),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 3) {
            _profileKey.currentState?.fetchData();
          }
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: isAdmin 
          ? [
              const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
              BottomNavigationBarItem(icon: _buildChatIcon(isAdmin), label: 'Chats'),
              const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
            ]
          : [
              const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
              BottomNavigationBarItem(icon: _buildChatIcon(isAdmin), label: 'Chats'),
              const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Blogs'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
            ],
      ),
    );
  }

  Widget _buildChatIcon(bool isAdmin) {
    if (_user == null) return const Icon(Icons.chat_bubble_outline);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('unread_messages')
          .stream(primaryKey: ['id'])
          .eq('user_id', _user!.id),
      builder: (context, snapshot) {
        int count = snapshot.data?.length ?? 0;
        bool hasMention = false;
        
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final userName = _user?.userMetadata?['full_name'] ?? '';
          for (var m in snapshot.data!) {
            if (m['content']?.toString().contains('@$userName') == true) {
              hasMention = true;
              break;
            }
          }
        }
        
        return Stack(
          children: [
            const Icon(Icons.chat_bubble_outline),
            if (count > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasMention ? Colors.orange : Colors.red, 
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasMention) ...[
                        const Text('@', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1)),
                        const SizedBox(width: 1),
                      ],
                      Text(
                        '$count', 
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTrekkerHub() {
    final bool isAdmin = _userRole == 'admin';
    if (isAdmin) return const SizedBox.shrink(); // Remove for Admin

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trekker Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _hubCard('The Trekker Daily', Icons.auto_stories_outlined, Colors.indigoAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen()));
              }),
              _hubCard('Summit Stories', Icons.landscape, Colors.deepPurple, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen(initialCategory: 'Summit')));
              }),
              _hubCard('Expedition Dispatch', Icons.campaign, Colors.redAccent, () {
                _showAnnouncementsList();
              }),
              _hubCard('Mission Debrief', Icons.report_problem_outlined, Colors.orange, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const UserComplaintsScreen()));
              }),
            ],
          ),
        ),
      ],
    );
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
}
