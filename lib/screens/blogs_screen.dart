import 'package:flutter/material.dart';
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

  final List<String> _categories = ['All', 'Summit', 'Trekking', 'Life', 'Wellness'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _fetchBlogs();
    _checkEligibility();
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

  Future<void> _fetchBlogs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client
          .from('blogs')
          .select('*, profiles(full_name, avatar_url)');
      
      if (widget.onlyMyBlogs && user != null) {
        query = query.eq('author_id', user.id);
      }

      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _allBlogs = response;
          if (_selectedCategory == 'All') {
            _filteredBlogs = response;
          } else {
            _filteredBlogs = response.where((b) => (b['category'] ?? '').toString().toLowerCase() == _selectedCategory.toLowerCase()).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      if (filter == 'Recent') {
        _filteredBlogs.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      } else if (filter == 'Trending' || filter == 'Popular') {
        _filteredBlogs.sort((a, b) => (b['upvotes_count'] ?? 0).compareTo(a['upvotes_count'] ?? 0));
      }
    });
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory = cat;
      if (cat == 'All') {
        _filteredBlogs = _allBlogs;
      } else {
        _filteredBlogs = _allBlogs.where((b) => (b['category'] ?? '').toString().toLowerCase() == cat.toLowerCase()).toList();
      }
      _applyFilter(_activeFilter);
    });
  }

  void _filterBlogs(String query) {
    setState(() {
      _filteredBlogs = _allBlogs.where((b) => 
        (b['title'] as String).toLowerCase().contains(query.toLowerCase()) ||
        (b['content'] as String).toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onlyMyBlogs ? 'My Stories' : 'The Trekker Daily', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
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
          ? const Center(child: CircularProgressIndicator())
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
                    ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildBlogCard(Map<String, dynamic> blog) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthor = user != null && blog['author_id'] == user.id;
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
            await Navigator.push(context, MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)));
            _fetchBlogs(); // Re-fetch to sync upvotes and comments count
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('READ STORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor, letterSpacing: 1)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Theme.of(context).primaryColor),
                        const Spacer(),
                        Text('By ${blog['profiles']?['full_name'] ?? 'Trekker'}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.arrow_upward, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
        ],
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

  @override
  void initState() {
    super.initState();
    _upvoteCount = widget.blog['upvotes_count'] ?? 0;
    _fetchComments();
    _checkUpvoteStatus();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await Supabase.instance.client
          .from('blog_comments')
          .select('*, profiles(full_name, avatar_url)')
          .eq('blog_id', widget.blog['id'])
          .order('created_at', ascending: false);
      if (mounted) setState(() { _comments = res; _isLoadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
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
    
    try {
      if (_isUpvoted) {
        await Supabase.instance.client.from('blog_upvotes').delete().eq('blog_id', widget.blog['id']).eq('user_id', user.id);
        if (mounted) setState(() { _isUpvoted = false; if (_upvoteCount > 0) _upvoteCount--; });
      } else {
        await Supabase.instance.client.from('blog_upvotes').insert({'blog_id': widget.blog['id'], 'user_id': user.id});
        if (mounted) setState(() { _isUpvoted = true; _upvoteCount++; });
      }
    } catch (_) {}
  }

  Future<void> _postComment() async {
    final msg = _commentCtrl.text.trim();
    if (msg.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('blog_comments').insert({'blog_id': widget.blog['id'], 'user_id': user.id, 'content': msg});
      _commentCtrl.clear();
      _fetchComments();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> gallery = widget.blog['gallery'] ?? [];
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = user != null && widget.blog['author_id'] == user.id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(backgroundColor: Colors.black38, child: const BackButton(color: Colors.white)),
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
                onPressed: () => Share.share('Check out this trek story: ${widget.blog['title']} on Trek India!'),
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
                        bottom: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(1 + gallery.length, (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImgIdx == index ? Colors.white : Colors.white38,
                            ),
                          )),
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
                      CircleAvatar(backgroundImage: NetworkImage(widget.blog['profiles']?['avatar_url'] ?? '')),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.blog['profiles']?['full_name'] ?? 'Trekker', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.blog['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      _upvoteButton(),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                  _isLoadingComments ? const Center(child: CircularProgressIndicator()) : _buildCommentsList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _upvoteButton() {
    return InkWell(
      onTap: _toggleUpvote,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isUpvoted ? Colors.orange : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_upward, color: _isUpvoted ? Colors.white : Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text('$_upvoteCount', style: TextStyle(color: _isUpvoted ? Colors.white : Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(backgroundColor: Colors.black, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _postComment)),
      ],
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
      try {
        await Supabase.instance.client.from('blog_comments').delete().eq('id', commentId);
        _fetchComments();
      } catch (_) {}
    }
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) return const Center(child: Text('No comments yet. Be the first to start the conversation!', style: TextStyle(color: Colors.grey, fontSize: 13)));
    
    final user = Supabase.instance.client.auth.currentUser;
    // Checking admin status via email pattern for the detail view context
    final bool isAdmin = (user != null && (user.email == 'admin@trek.com' || user.email?.contains('admin') == true)); 

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        final bool isMyComment = user != null && c['user_id'] == user.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(imageUrl: c['profiles']?['avatar_url'], name: c['profiles']?['full_name'], radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c['profiles']?['full_name'] ?? 'Trekker', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM dd').format(DateTime.parse(c['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        const Spacer(),
                        if (isMyComment || isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: Colors.red,
                            onPressed: () => _deleteComment(c['id']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.blueGrey, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
