import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/user_avatar.dart';
import 'add_blog_screen.dart';
import 'edit_blog_screen.dart';

class BlogsScreen extends StatefulWidget {
  final bool onlyMyBlogs;
  final String? initialCategory;
  const BlogsScreen({super.key, this.onlyMyBlogs = false, this.initialCategory});

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  List<dynamic> _allBlogs = [];
  List<dynamic> _filteredBlogs = [];
  bool _isLoading = true;
  bool _canWriteBlog = false;
  String _activeFilter = 'Recent'; 
  String _selectedCategory = 'All';
  String _userRole = 'user';
  final _searchCtrl = TextEditingController();
  RealtimeChannel? _blogSubscription;

  final List<String> _categories = ['All', 'Summit', 'Tripking', 'Life', 'Wellness', 'Review', 'Gear', 'Wildlife', 'History', 'Solo', 'Group'];

  Future<void> _fetchBlogs({bool showLoading = true}) async {
    try {
      if (showLoading) setState(() => _isLoading = true);
      final user = Supabase.instance.client.auth.currentUser;
      // Manual join due to schema cache issues
      final blogsRes = await Supabase.instance.client
          .from('blogs')
          .select('*')
          .order('created_at', ascending: false);
      
      final blogsList = List<Map<String, dynamic>>.from(blogsRes);
      final authorIds = blogsList.map((b) => b['user_id'] ?? b['author_id']).where((id) => id != null).toSet().toList();
      
      final profilesRes = authorIds.isEmpty 
          ? [] 
          : await Supabase.instance.client
              .from('profiles')
              .select('id, full_name, avatar_url')
              .filter('id', 'in', authorIds);
          
      final profilesMap = {for (var p in profilesRes) p['id']: p};
      
      final List<dynamic> enrichedBlogs = blogsList.map((b) {
        final blog = Map<String, dynamic>.from(b);
        final uid = b['user_id'] ?? b['author_id'];
        blog['user_id'] = uid;
        blog['profiles'] = profilesMap[uid];
        return blog;
      }).toList();
      
      

      List<dynamic> finalBlogs = enrichedBlogs;
      if (widget.onlyMyBlogs && user != null) {
        finalBlogs = enrichedBlogs.where((b) => b['user_id'] == user.id).toList();
      }
      
      if (mounted) {
        setState(() {
          _allBlogs = finalBlogs;
          _filterAndSortBlogs();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('BLOG FETCH ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAndSortBlogs() {
    List<dynamic> filtered = _allBlogs;
    
    // Category Filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((b) => 
        (b['category'] ?? '').toString().toLowerCase() == _selectedCategory.toLowerCase() ||
        (b['tags'] as List?)?.any((t) => t.toString().toLowerCase() == _selectedCategory.toLowerCase()) == true
      ).toList();
    }
    
    // Search Filter
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      filtered = filtered.where((b) => 
        (b['title'] ?? '').toString().toLowerCase().contains(q) ||
        (b['content'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }

    // Sort
    if (_activeFilter == 'Recent') {
      filtered.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    } else {
      filtered.sort((a, b) => (b['upvotes_count'] ?? 0).compareTo(a['upvotes_count'] ?? 0));
    }

    setState(() => _filteredBlogs = filtered);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _fetchBlogs();
    _checkEligibility();
    _setupRealtime();
  }

  void _setupRealtime() {
    _blogSubscription = Supabase.instance.client
        .channel('public:blogs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blogs',
          callback: (payload) {
            debugPrint('BLOGS LIST: Realtime Update Detected');
            _fetchBlogs(showLoading: false);
          },
        )
        .subscribe();
  }

  Future<void> _checkEligibility() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _userRole = profile?['role'] ?? 'user');

      if (_userRole == 'admin') {
        if (mounted) setState(() => _canWriteBlog = true);
        return;
      }
      
      final bookings = await Supabase.instance.client.from('bookings').select('id').eq('user_id', user.id).limit(1);
      if (bookings.isNotEmpty) {
        if (mounted) setState(() => _canWriteBlog = true);
      }
    }
  }

  void _applyFilter(String filter) {
    _activeFilter = filter;
    _filterAndSortBlogs();
  }

  void _selectCategory(String cat) {
    _selectedCategory = cat;
    _filterAndSortBlogs();
  }

  void _filterBlogs(String query) {
    _filterAndSortBlogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onlyMyBlogs ? 'My Blogs' : 'The Trip Daily', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onlyMyBlogs ? const BackButton() : null,
        actions: [
          if (_canWriteBlog)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 26),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBlogScreen()));
                if (result == true) _fetchBlogs();
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBlogs),
        ],
      ),
      body: _isLoading 
          ? _buildFullPageShimmer()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildFilterRow(),
                        const SizedBox(height: 16),
                        _buildCategoryRow(),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _isLoading 
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildShimmerCard(),
                          childCount: 3,
                        ),
                      )
                    : _filteredBlogs.isEmpty
                    ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No stories found.', style: TextStyle(color: Colors.grey)))))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBlogCard(_filteredBlogs[index]),
                          childCount: _filteredBlogs.length,
                        ),
                      ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _filterBlogs,
      decoration: InputDecoration(
        hintText: 'Search stories...',
        prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _filterChip('Recent'),
        const SizedBox(width: 10),
        _filterChip('Trending'),
        const SizedBox(width: 10),
        _filterChip('Popular'),
      ],
    );
  }

  Widget _buildCategoryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(c),
            selected: _selectedCategory == c,
            onSelected: (_) => _selectCategory(c),
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            labelStyle: TextStyle(color: _selectedCategory == c ? Theme.of(context).primaryColor : Colors.grey, fontWeight: FontWeight.bold),
          ),
        )).toList(),
      ),
    );
  }

  Widget _filterChip(String label) {
  bool selected = _activeFilter == label;

  return GestureDetector(
    onTap: () => _applyFilter(label),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xFFD32F2F) : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFD32F2F) : Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
  );
}

  Widget _buildBlogCard(Map<String, dynamic> blog) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthor = user != null && blog['user_id'] == user.id;
    final isAdmin = _userRole == 'admin';
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)));
            if (result == true) {
              _fetchBlogs(showLoading: false);
            }
          },
          borderRadius: BorderRadius.circular(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildBlogImageCarousel(blog),
                  if (isAuthor || isAdmin)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _actionIcon(Icons.edit, Colors.blue, () async {
                            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBlogScreen(blog: blog)));
                            if (res == true) _fetchBlogs();
                          }),
                          const SizedBox(width: 8),
                          _actionIcon(Icons.delete, Colors.red, () => _confirmDelete(blog['id'])),
                        ],
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text(blog['read_time'] ?? '5 min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const Spacer(),
                        _upvoteIndicator(blog['upvotes_count'] ?? 0),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(blog['title'] ?? 'Title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 8),
                    if (blog['tags'] != null && (blog['tags'] as List).isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: (blog['tags'] as List).take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                          child: Text('#$tag', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        )).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: blog['profiles']?['avatar_url'], 
                          name: blog['profiles']?['full_name'],
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                        Text('By ${blog['profiles']?['full_name'] ?? 'Trip'}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('READ STORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor, letterSpacing: 1)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Theme.of(context).primaryColor),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: IconButton(icon: Icon(icon, color: color, size: 18), onPressed: onTap),
    );
  }

  void _confirmDelete(String blogId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            Navigator.pop(c);
            await Supabase.instance.client.from('blogs').delete().eq('id', blogId);
            _fetchBlogs();
          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _upvoteIndicator(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF4500)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.thumb_up, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            '$count', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: GlassShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBlock(width: double.infinity, height: 220, borderRadius: 25),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBlock(width: 200, height: 20),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const ShimmerBlock(width: 30, height: 30, shape: BoxShape.circle),
                      const SizedBox(width: 10),
                      const ShimmerBlock(width: 100, height: 12),
                      const Spacer(),
                      const ShimmerBlock(width: 60, height: 25, borderRadius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogImageCarousel(Map<String, dynamic> blog) {
    final List<String> images = [blog['image_url'] ?? ''];
    // Mock additional images for carousel
    if (images.length < 2) images.add(blog['image_url'] ?? '');

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            itemBuilder: (context, idx) {
              return Hero(
                tag: 'blog_img_${blog['id']}_$idx',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: images[idx],
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[200]),
                  ),
                ),
              );
            }
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('1/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullPageShimmer() {
    return GlassShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: List.generate(5, (i) => const ShimmerBlock(width: 80, height: 40, margin: EdgeInsets.only(right: 10), borderRadius: 10)),
              ),
            ),
            ...List.generate(3, (i) => _buildShimmerCard()),
          ],
        ),
      ),
    );
  }
}

class BlogDetailScreen extends StatefulWidget {
  final Map<String, dynamic> blog;
  const BlogDetailScreen({super.key, required this.blog});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final _commentCtrl = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  bool _isUpvoted = false;
  int _upvoteCount = 0;
  int _currentImgIdx = 0;
  bool _isPostingComment = false;
  bool _somethingChanged = false;
  RealtimeChannel? _detailSubscription;
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    _upvoteCount = widget.blog['upvotes_count'] ?? 0;
    _fetchComments();
    _checkUpvoteStatus();
    _setupRealtime();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _myProfile = res);
    }
  }

  void _setupRealtime() {
    _detailSubscription = Supabase.instance.client
        .channel('blog_detail_${widget.blog['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blog_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'blog_id',
            value: widget.blog['id'],
          ),
          callback: (payload) {
            debugPrint('BLOG DETAIL: Comments updated');
            _fetchComments();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blogs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.blog['id'],
          ),
          callback: (payload) {
            debugPrint('BLOG DETAIL: Blog metadata updated');
            if (payload.newRecord != null) {
              if (mounted) setState(() {
                _upvoteCount = payload.newRecord!['upvotes_count'] ?? 0;
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _detailSubscription?.unsubscribe();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchComments({bool showLoading = true}) async {
    try {
      if (showLoading) setState(() => _isLoadingComments = true);
      final blogId = widget.blog['id'];
      debugPrint('DEBUG: Fetching comments for Blog ID: $blogId');
      
      final res = await Supabase.instance.client
          .from('blog_comments')
          .select('*, profiles:user_id(*)')
          .eq('blog_id', blogId)
          .order('created_at', ascending: false);
      
      debugPrint('DEBUG: Comments fetched count: ${res.length}');
      debugPrint('DEBUG: First comment raw: ${res.isNotEmpty ? res[0] : "NONE"}');
      
      if (mounted) setState(() { _comments = res; _isLoadingComments = false; });
    } catch (e) {
      debugPrint('DEBUG: Fetch Error: $e');
      // Final attempt: Simple select
      try {
        final res = await Supabase.instance.client.from('blog_comments').select('*').eq('blog_id', widget.blog['id']);
        if (mounted) setState(() { _comments = res; _isLoadingComments = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _checkUpvoteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client.from('blog_upvotes').select('id').eq('blog_id', widget.blog['id']).eq('user_id', user.id).maybeSingle();
      if (mounted) setState(() => _isUpvoted = res != null);
    } catch (_) {}
  }

  Future<void> _toggleUpvote() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final originalStatus = _isUpvoted;
    final originalCount = _upvoteCount;

    // Optimistic UI Update
    if (mounted) {
      setState(() {
        if (_isUpvoted) {
          _isUpvoted = false;
          if (_upvoteCount > 0) _upvoteCount--;
        } else {
          _isUpvoted = true;
          _upvoteCount++;
        }
        _somethingChanged = true;
      });
    }

    try {
      if (originalStatus) {
        await Supabase.instance.client.from('blog_upvotes').delete().eq('blog_id', widget.blog['id']).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('blog_upvotes').insert({'blog_id': widget.blog['id'], 'user_id': user.id});
      }
    } catch (e) {
      debugPrint('UPVOTE ERROR: $e');
      // Rollback on failure
      if (mounted) {
        setState(() {
          _isUpvoted = originalStatus;
          _upvoteCount = originalCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update upvote: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _postComment() async {
    final msg = _commentCtrl.text.trim();
    if (msg.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isPostingComment = true);
      
      // Optimistic UI: Add to local list immediately
      final tempComment = {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'blog_id': widget.blog['id'],
        'user_id': user.id,
        'content': msg,
        'created_at': DateTime.now().toIso8601String(),
        'profiles': _myProfile ?? {
          'full_name': 'You',
          'avatar_url': null,
        }
      };
      
      if (mounted) {
        setState(() {
          _comments.insert(0, tempComment);
        });
      }

      await Supabase.instance.client.from('blog_comments').insert({
        'blog_id': widget.blog['id'], 
        'user_id': user.id, 
        'content': msg
      });
      
      _commentCtrl.clear();
      _somethingChanged = true;
      
      // Refresh to get the real ID and profile data from server
      await _fetchComments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment added successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('COMMENT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post comment: $e'), backgroundColor: Colors.red));
        _fetchComments(); // Revert local list to server state
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> gallery = widget.blog['gallery'] ?? [];
    final user = Supabase.instance.client.auth.currentUser;
    final authorId = widget.blog['user_id'];
    final isOwner = user != null && authorId == user.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _somethingChanged);
      },
      child: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black38, 
                child: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context, _somethingChanged),
                )
              ),
            ),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () async {
                    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBlogScreen(blog: widget.blog)));
                    if (res == true) Navigator.pop(context, true);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => Share.share('Check out this trip story: ${widget.blog['title']} on trekwithmussafirr!'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'blog_img_${widget.blog['id']}',
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      onPageChanged: (i) => setState(() => _currentImgIdx = i),
                      itemCount: 1 + gallery.length,
                      itemBuilder: (c, i) => CachedNetworkImage(
                        imageUrl: i == 0 ? widget.blog['image_url'] : gallery[i-1],
                        fit: BoxFit.cover
                      ),
                    ),
                    if (gallery.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(1 + gallery.length, (idx) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImgIdx == idx ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImgIdx == idx ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        ),
                      ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                        child: Text('${_currentImgIdx+1}/${1 + gallery.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              transform: Matrix4.translationValues(0, -30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: widget.blog['profiles']?['avatar_url'], 
                        name: widget.blog['profiles']?['full_name'],
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.blog['profiles']?['full_name'] ?? 'Trip', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.blog['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      _upvoteButton(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.blog['tags'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        children: (widget.blog['tags'] as List).map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ),
                  Text(widget.blog['title'] ?? '', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('${widget.blog['read_time'] ?? '5 min'} read', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(widget.blog['content'] ?? '', style: const TextStyle(fontSize: 17, height: 1.8, color: Colors.blueGrey)),
                  const SizedBox(height: 30),
                  
                  // Gallery removed from bottom as it is now in the top carousel
                  
                  const Text('Community Discussion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  _buildCommentInput(),
                  const SizedBox(height: 20),
                  _isLoadingComments 
                    ? _buildCommentsShimmer()
                    : _buildCommentsList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    ),
  );
}

  Widget _upvoteButton() {
    return InkWell(
      onTap: _toggleUpvote,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: _isUpvoted 
            ? const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF4500)])
            : LinearGradient(colors: [Colors.grey.withOpacity(0.05), Colors.grey.withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isUpvoted ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined, 
              color: _isUpvoted ? Colors.white : Colors.orange, 
              size: 20
            ),
            const SizedBox(width: 10),
            Text(
              '$_upvoteCount', 
              style: TextStyle(
                color: _isUpvoted ? Colors.white : Colors.orange, 
                fontWeight: FontWeight.w900,
                fontSize: 15
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                hintText: 'Share your thoughts...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isPostingComment ? null : _postComment,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.black87, Colors.black]),
              ),
              child: Center(
                child: _isPostingComment 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirmed == true) {
      // Optimistic UI: Remove from local list first
      final originalComments = List.from(_comments);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
          _somethingChanged = true;
        });
      }

      try {
        await Supabase.instance.client.from('blog_comments').delete().eq('id', commentId);
        // Realtime will handle the update if active, but we already updated locally.
        // We still fetch to ensure consistency if needed, but in background.
        _fetchComments(showLoading: false);
      } catch (e) {
        debugPrint('DELETE ERROR: $e');
        // Rollback on error
        if (mounted) {
          setState(() => _comments = originalComments);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete comment. Please try again.'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) return const Center(child: Text('No comments yet. Be the first to start the conversation!', style: TextStyle(color: Colors.grey, fontSize: 13)));
    
    final user = Supabase.instance.client.auth.currentUser;
    // Checking admin status via email pattern for the detail view context
    final bool isAdmin = (user != null && (user.email == 'admin@trip.com' || user.email?.contains('admin') == true)); 

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        final bool isMyComment = user != null && c['user_id'] == user.id;
        final profile = c['profiles'] ?? c['user'];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return FadeInUp(
          duration: Duration(milliseconds: 300 + (i * 100)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(imageUrl: profile?['avatar_url'], name: profile?['full_name'], radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?['full_name'] ?? 'Traveler', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(c['created_at'])), 
                            style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    if (isMyComment || isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red.withOpacity(0.7),
                        onPressed: () => _deleteComment(c['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    c['content'] ?? '', 
                    style: TextStyle(
                      fontSize: 14, 
                      color: isDark ? Colors.white70 : Colors.black87, 
                      height: 1.5,
                      letterSpacing: 0.2
                    )
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsShimmer() {
    return GlassShimmer(
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShimmerBlock(width: 32, height: 32, shape: BoxShape.circle),
                  const SizedBox(width: 12),
                  const ShimmerBlock(width: 100, height: 12),
                ],
              ),
              const SizedBox(height: 12),
              const ShimmerBlock(width: double.infinity, height: 40, borderRadius: 12),
            ],
          ),
        )),
      ),
    );
  }
}
