import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/database_service.dart';
import 'admin_group_analytics_screen.dart';
import '../widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/whatsapp_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/trip.dart';
import 'package:collection/collection.dart';
import 'media_preview_screen.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _client = Supabase.instance.client;
  DateTime? _selectedDate;
  bool _isLoading = true;
  List<dynamic> _tripGroups = [];
  List<TripCategory> _availableCategories = [];
  int _tabIndex = 0; // 0 for Active, 1 for Archived

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchGroups();
  }

  Future<void> _fetchCategories() async {
    final cats = await DatabaseService().fetchCategories();
    if (mounted) setState(() => _availableCategories = cats);
  }

  Future<void> _fetchGroups() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Joined Data
      final allBookings = await _client.from('bookings').select('*, trip_groups(*), trips(*), profiles(*)').order('created_at', ascending: false);
      final allStaff = await _client.from('trip_group_staff').select('*, profiles!user_id(*)');
      
      debugPrint('Admin Bookings Count: ${allBookings.length}');
      
      Map<String, dynamic> groups = {};

      void addToGroup(String groupKey, dynamic trip, String date, dynamic profile, double price, String? realGroupId, {String? hikerNumber, String? hikerEmail, String? pickupLocation, int? travelers, dynamic addons, String? paymentStatus, String? paymentMethod, String? paymentProofUrl, String? bookingId}) {
        if (trip == null) return;
        
        if (_selectedDate != null) {
           try {
             final dParsed = DateTime.parse(date);
             if (dParsed.year != _selectedDate!.year || dParsed.month != _selectedDate!.month || dParsed.day != _selectedDate!.day) {
                return;
             }
           } catch (_) { 
             return; 
           }
        }

        if (!groups.containsKey(groupKey)) {
          groups[groupKey] = {
            'trip_id': trip['id'],
            'trip': trip,
            'date': date,
            'total_revenue': 0.0,
            'participants': [],
            'group_id': realGroupId,
          };
        }
        if (profile != null) {
          final participant = Map<String, dynamic>.from(profile);
          participant['hiker_number'] = hikerNumber;
          participant['hiker_email'] = hikerEmail;
          participant['pickup_location'] = pickupLocation;
          participant['travelers'] = travelers ?? 1;
          participant['addons'] = addons;
          participant['payment_status'] = paymentStatus;
          participant['payment_method'] = paymentMethod;
          participant['payment_proof_url'] = paymentProofUrl;
          participant['booking_id'] = bookingId;
          participant['total_price'] = price;
          groups[groupKey]['participants'].add(participant);
          groups[groupKey]['total_revenue'] += price;
        }
        if (realGroupId != null && groups[groupKey]['group_id'] == null) {
            groups[groupKey]['group_id'] = realGroupId;
        }
      }

      // 2. Process Bookings Data
      for (var b in allBookings) {
        try {
          final trip = b['trips'] ?? {
            'id': b['trip_id'],
            'title': b['trip_name'] ?? 'Unscheduled Trip',
            'location': 'Unknown Location',
          };

          final String bStatus = b['status']?.toString().toLowerCase() ?? b['payment_status']?.toString().toLowerCase() ?? '';
          final String gStatus = b['trip_groups']?['status']?.toString().toLowerCase() ?? '';
          bool isCompleted = bStatus == 'completed' || gStatus == 'completed';

          if (_tabIndex == 0 && isCompleted) continue;
          if (_tabIndex == 1 && !isCompleted) continue;

          final String rawDate = b['trip_date'] ?? b['booking_date'] ?? 'TBD';
          final String groupKey = '${b['trip_id']}_$rawDate';
          final userProfile = b['profiles'];
          
          final String? realGroupId = b['trip_groups']?['id']?.toString() ?? b['group_id']?.toString();
          
          addToGroup(
            groupKey, 
            trip, 
            rawDate, 
            userProfile, 
            double.tryParse(b['total_price'].toString()) ?? 0, 
            realGroupId,
            hikerNumber: b['hiker_number']?.toString(),
            hikerEmail: b['hiker_email']?.toString(),
            pickupLocation: b['pickup_location']?.toString(),
            travelers: int.tryParse(b['travelers']?.toString() ?? '1') ?? 1,
            addons: b['addons'],
            paymentStatus: b['payment_status']?.toString(),
            paymentMethod: b['payment_method']?.toString(),
            paymentProofUrl: b['payment_proof_url']?.toString(),
            bookingId: b['id']?.toString(),
          );

          // Add additional travelers if any
          if (b['traveler_details'] != null) {
            final extras = b['traveler_details'] as List;
            for (var ext in extras) {
              addToGroup(
                groupKey,
                b['trip'],
                rawDate,
                {
                  'full_name': ext['name'] ?? 'Additional Hiker',
                  'avatar_url': null,
                  'id': 'extra_${b['id']}',
                  'is_extra': true,
                  'age': ext['age'],
                },
                0, // Price already accounted for in primary
                realGroupId,
                hikerNumber: b['hiker_number']?.toString(),
                hikerEmail: b['hiker_email']?.toString(),
                addons: null,
                paymentStatus: b['payment_status']?.toString(),
                paymentMethod: b['payment_method']?.toString(),
                paymentProofUrl: b['payment_proof_url']?.toString(),
                bookingId: b['id']?.toString(),
              );
            }
          }
        } catch (innerE) {
          debugPrint('Error processing individual booking: $innerE');
        }
      }

      // 3. Process Staff Data
      for (var s in allStaff) {
        try {
          final tDate = s['deployment_date'] ?? ''; 
          final tId = s['trip_id'];
          final gKey = '${tId}_$tDate';
          if (groups.containsKey(gKey)) {
             final staffProfile = s['profiles'];
             if (staffProfile != null) {
                groups[gKey]['participants'].add(staffProfile);
             }
          }
        } catch (_) {}
      }

      // 3. Process Staff Data
      for (var s in allStaff) {
        // ... staff processing
      }

      // 4. Resolve Addon Names (Manual Join)
      final allGears = await _client.from('gears').select('id, name');
      final gearMap = {for (var g in allGears) g['id']: g['name']};

      for (var g in groups.values) {
        for (var p in g['participants']) {
          if (p['addons'] != null) {
            final addons = p['addons'] as List;
            for (var a in addons) {
              a['gear_name'] = gearMap[a['gear_id']] ?? 'Gear Item';
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _tripGroups = groups.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CRITICAL: Admin Bookings Fetch Failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MANAGE BOOKINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: _selectedDate != null ? Colors.blueAccent : Colors.white),
            onPressed: () async {
               final d = await showDatePicker(
                 context: context, 
                 initialDate: _selectedDate ?? DateTime.now(), 
                 firstDate: DateTime(2024), 
                 lastDate: DateTime(2030)
               );
               if (d != null) {
                 setState(() => _selectedDate = d);
                 _fetchGroups();
               } else if (_selectedDate != null) {
                 setState(() => _selectedDate = null);
                 _fetchGroups();
               }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
               _tabItem(0, 'ACTIVE TRIPS'),
               _tabItem(1, 'TRIP ARCHIVE'),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              if (_selectedDate != null) Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text('FILTERING DATE: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const Spacer(),
                    TextButton(
                      onPressed: () { setState(() => _selectedDate = null); _fetchGroups(); }, 
                      child: const Text('CLEAR', style: TextStyle(fontSize: 10, color: Colors.red))
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchGroups,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildAnalyticsCards(),
                          const SizedBox(height: 24),
                          const Text('TRIP MANAGEMENT GRID', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ..._tripGroups.map((g) => _buildGroupCard(g)).toList(),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(dynamic g) {
    final trip = g['trip'];
    String dateStr = 'TBD';
    try {
      if (g['date'] != null && g['date'].toString().isNotEmpty) {
         dateStr = DateFormat('EEEE, MMM dd yyyy').format(DateTime.parse(g['date']));
      }
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10)],
        border: Border.all(color: _tabIndex == 1 ? Colors.blueGrey.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(trip['title'] ?? 'Generic Trip', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${g['participants'].length} ${_getCategoryLabel(trip['category'])}', 
                  style: const TextStyle(color: Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13, fontWeight: FontWeight.bold)),
              Text('₹${g['total_revenue'].toInt()}', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('GROUP ROSTER', style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              Text('${g['participants'].length} MEMBERS', style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: g['participants'].map<Widget>((p) => _buildTripDetailCard(p)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_tabIndex == 0) Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (c) => AdminGroupAnalyticsScreen(tripId: trip['id'], tripDate: g['date'])));
                    _fetchGroups();
                  },
                  icon: const Icon(Icons.groups_outlined, color: Colors.white, size: 16),
                  label: const Text('MANAGE GROUP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () async {
                   final ok = await showDialog<bool>(
                     context: context,
                     builder: (c) => AlertDialog(
                       title: const Text('TRIP COMPLETION'),
                       content: Text('Mark ${trip['title']} as COMPLETED?'),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(c), child: const Text('NO')),
                         ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('COMPLETE')),
                       ],
                     )
                   );
                   if (ok == true) {
                     final db = DatabaseService();
                     final success = await db.completeTrip(groupId: g['id'], distance: double.tryParse(trip['distance']?.toString() ?? '10') ?? 10.0);
                     if (success) {
                        _fetchGroups();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip Completed & Stats Updated!'), backgroundColor: Colors.green));
                     }
                   }
                },
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Complete Trip',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailCard(dynamic p) {
    if (p == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String name = p['full_name']?.toString() ?? 'Trip';
    final String? email = p['hiker_email']?.toString() ?? p['email']?.toString();
    final String? phone = p['hiker_number']?.toString() ?? p['phone_number']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(radius: 20, imageUrl: p['avatar_url'], name: name),
              if (p['aadhar_url'] != null || p['medical_certificate_url'] != null)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: Icon(Icons.verified, size: 10, color: Colors.blue),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   "${name.toUpperCase()}${p['is_extra'] == true ? ' (ADD-ON MEMBER)' : ''}",
                   style: TextStyle(
                     fontWeight: FontWeight.w900,
                     fontSize: 13,
                     color: isDark ? Colors.white : Colors.black87,
                     letterSpacing: -0.3,
                   ),
                 ),
                 if (p['age'] != null) Text('AGE: ${p['age']}', style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: _getPaymentStatusColor(p['payment_status']).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         (p['payment_status'] ?? 'PENDING').toString().toUpperCase(),
                         style: TextStyle(color: _getPaymentStatusColor(p['payment_status']), fontSize: 8, fontWeight: FontWeight.bold),
                       ),
                     ),
                     if (p['payment_method'] != null) ...[
                       const SizedBox(width: 8),
                       Text(p['payment_method'].toString().toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                     ],
                   ],
                 ),
                if (email != null && email.isNotEmpty && email != 'null') ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 11, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone != null && phone.isNotEmpty && phone != 'null') ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 11, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (p['addons'] != null && (p['addons'] as List).isNotEmpty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: (p['addons'] as List).map((a) => "${a['quantity']}x ${a['gear_name']}").join('\n'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.orange),
              ),
            ),
          ],
            const SizedBox(width: 8),
            if (p['payment_status'] == 'Verifying') 
              IconButton(
                onPressed: () => _showPaymentVerificationDialog(p),
                icon: const Icon(Icons.account_balance_outlined, color: Colors.orange, size: 20),
                tooltip: 'Verify Payment',
              ),
            InkWell(
              onTap: () => _showContactOptions(context, p),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Color(0xFF25D366)),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showDocumentViewer(p),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined, size: 18, color: Colors.indigo),
              ),
            ),
          ],
        ),
      );
  }

  void _showContactOptions(BuildContext context, dynamic p) {
    final String phone = p['hiker_number']?.toString() ?? p['phone_number']?.toString() ?? '';
    if (phone.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call Participant'),
              onTap: () {
                Navigator.pop(c);
                launchUrl(Uri.parse("tel:$phone"));
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
              title: const Text('WhatsApp Message'),
              onTap: () {
                Navigator.pop(c);
                final String formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
                final String webUrl = "https://wa.me/$formattedPhone?text=${Uri.encodeComponent('Hello from trekwithmussafirr regarding your booking!')}";
                launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAnalyticsCards() {
    double totalRevenue = _tripGroups.fold(0, (sum, g) => sum + (g['total_revenue'] as double));
    int totalParticipants = _tripGroups.fold(0, (sum, g) => sum + (g['participants'].length as int));

    return Row(
      children: [
        Expanded(child: _analyticsCard('ACTIVE TRIPS', '${_tripGroups.length}', Colors.blue, Icons.map_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _analyticsCard('TOTAL TRAVELERS', '$totalParticipants', Colors.orange, Icons.groups_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _analyticsCard('TOTAL REVENUE', '₹${totalRevenue.toInt()}', Colors.green, Icons.account_balance_wallet_outlined)),
      ],
    );
  }

  Widget _analyticsCard(String label, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    bool selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tabIndex = index);
          _fetchGroups();
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blueAccent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(String? categoryName) {
    if (categoryName == null) return 'TRAVELERS';
    final cat = _availableCategories.firstWhereOrNull((c) => c.name == categoryName);
    if (cat != null && cat.badgeLabel != null) {
      return '${cat.badgeLabel}S'; // e.g. "TREKKERS", "RIDERS"
    }
    return 'TRAVELERS';
  }
  void _showDocumentViewer(dynamic profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SizedBox(width: 40, child: Divider(thickness: 4))),
            const SizedBox(height: 24),
            Text('VERIFICATION DOCUMENTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 32),
            _docRow('AADHAR CARD', profile?['aadhar_url']),
            _docRow('MEDICAL CERTIFICATE', profile?['medical_certificate_url']),
            _docRow('DECLARATION FORM', profile?['declaration_url']),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Access granted to ${profile?['full_name']?.toString().toUpperCase()}\'s safety records.',
                style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _docRow(String label, String? url) {
    bool hasDoc = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(hasDoc ? 'Digitally Verified' : 'Missing Document', style: TextStyle(color: hasDoc ? Colors.green : Colors.red, fontSize: 10)),
            ],
          ),
          if (hasDoc)
            ElevatedButton.icon(
              onPressed: () {
                final lowerUrl = url.toLowerCase();
                final isMedia = lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || lowerUrl.contains('.png') || 
                                lowerUrl.contains('.gif') || lowerUrl.contains('.pdf');
                if (isMedia) {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => MediaPreviewScreen(url: url, title: label)));
                } else {
                  launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
                }
              },
              icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
              label: const Text('VIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )
          else
            const Icon(Icons.error_outline, color: Colors.redAccent),
        ],
      ),
    );
  }
  Color _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
      case 'confirmed': return Colors.green;
      case 'verifying': return Colors.orange;
      case 'pending': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showPaymentVerificationDialog(dynamic p) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('VERIFY PAYMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hiker: ${p['full_name']}'),
            const SizedBox(height: 16),
            if (p['payment_proof_url'] != null && p['payment_proof_url'] != 'null')
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  p['payment_proof_url'], 
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) => const Center(child: Text('Proof image failed to load', style: TextStyle(color: Colors.red, fontSize: 10))),
                ),
              )
            else
              const Text('No screenshot attached.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Amount to verify: ₹${p['total_price']?.toInt() ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
            const SizedBox(height: 8),
            Text('Method: ${p['payment_method']?.toString().toUpperCase() ?? 'UNKNOWN'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await _client.from('bookings').update({
                'payment_status': 'Pending',
                'payment_proof_url': null,
              }).eq('id', p['booking_id'] ?? p['id']);
              
              final db = DatabaseService();
              await db.createNotification(
                userId: p['user_id'],
                title: 'Payment Proof Rejected',
                body: 'Your payment screenshot for ${p['trip_name'] ?? 'Trip'} was rejected. Please upload a clear receipt.',
                category: 'billing',
              );

              Navigator.pop(c);
              _fetchGroups();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Rejected. User notified.'), backgroundColor: Colors.red));
            },
            child: const Text('REJECT', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _client.from('bookings').update({
                'payment_status': 'Paid',
                'paid_amount': p['total_price'],
              }).eq('id', p['booking_id'] ?? p['id']);
              
              final db = DatabaseService();
              await db.createNotification(
                userId: p['user_id'],
                title: 'Payment Verified!',
                body: 'Great news! Your payment for ${p['trip_name'] ?? 'Trip'} has been verified. Get ready for adventure!',
                category: 'billing',
              );

              // Log to payment_logs for wallet balance synchronization
              // Unified mapping for user_id or author_id
              final authorId = p['user_id'] ?? p['author_id'];
              await _client.from('payment_logs').insert({
                'user_id': authorId,
                'amount': p['total_price'],
                'payment_type': 'CREDIT',
                'description': 'Verified Payment for ${p['trip_name'] ?? 'Trip'}',
                'is_incoming': true,
                'booking_id': p['booking_id'] ?? p['id'],
              });

              Navigator.pop(c);
              _fetchGroups();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Verified!'), backgroundColor: Colors.green));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('CONFIRM PAYMENT'),
          ),
        ],
      ),
    );
  }
}
