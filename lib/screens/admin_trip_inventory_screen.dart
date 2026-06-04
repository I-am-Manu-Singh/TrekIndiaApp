import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'edit_trip_screen.dart';
import '../models/trip.dart';
import 'blogs_screen.dart';
import '../services/xlsx_service.dart';
import '../services/database_service.dart';

class AdminTripInventoryScreen extends StatefulWidget {
  const AdminTripInventoryScreen({super.key});

  @override
  State<AdminTripInventoryScreen> createState() => _AdminTripInventoryScreenState();
}

class _AdminTripInventoryScreenState extends State<AdminTripInventoryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _trips = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  

  // CSV column headers — must match _rowFromTrip() order
  static const List<String> _csvHeaders = [
    'id', 'title', 'location', 'category', 'duration', 'base_price',
    'discount_percent', 'reward_points', 'difficulty', 'altitude',
    'best_months', 'peak_elevation', 'trail_type', 'start_point',
    'package_type', 'rating', 'total_distance', 'image_url',
    'description',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('trips').select().order('title', ascending: true);
      final cats = await DatabaseService().fetchCategories();
      if (mounted) {
        setState(() {
          _trips = res;
          _categories = ['All', ...cats.map((c) => c.name)];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTrip(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('REMOVE TRIP?'),
        content: const Text('This will permanently remove this trip. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ABORT')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _client.from('trips').delete().eq('id', id);
        _fetchTrips();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip removed.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT: All trips → Excel (.xlsx)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _exportXlsx() async {
    if (_trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trips to export.'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(), SizedBox(width: 16), Text('Building Excel file...'),
        ]),
      ))),
    );
    try {
      final rows = <List<dynamic>>[_csvHeaders];
      for (final trip in _trips) {
        rows.add(_rowFromTrip(trip));
      }
      final bytes = XlsxService.buildXlsx(rows);
      final fileName = 'trips_export_${DateTime.now().millisecondsSinceEpoch}';
      final path = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) {
        Navigator.pop(context);
        if (path != null && path.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Exported ${_trips.length} trips successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT: All trips → CSV download
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trips to export.'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(), SizedBox(width: 16), Text('Exporting CSV...'),
        ]),
      ))),
    );

    try {
      final rows = <List<dynamic>>[_csvHeaders];
      for (final trip in _trips) {
        rows.add(_rowFromTrip(trip));
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvString));

      final fileName = 'trips_export_${DateTime.now().millisecondsSinceEpoch}';
      final path = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        if (path != null && path.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Exported ${_trips.length} trips successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<dynamic> _rowFromTrip(Map<String, dynamic> t) => [
    t['id'] ?? '',
    t['title'] ?? '',
    t['location'] ?? '',
    t['category'] ?? '',
    t['duration'] ?? '',
    t['base_price'] ?? 0,
    t['discount_percent'] ?? 0,
    t['reward_points'] ?? 0,
    t['difficulty'] ?? '',
    t['altitude'] ?? '',
    t['best_months'] ?? '',
    t['peak_elevation'] ?? '',
    t['trail_type'] ?? '',
    t['start_point'] ?? '',
    t['package_type'] ?? '',
    t['rating'] ?? 5.0,
    t['total_distance'] ?? '',
    t['image_url'] ?? '',
    (t['description'] ?? '').toString().replaceAll('\n', ' '),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // IMPORT: CSV or Excel file → upsert trips in Supabase
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    final fileName = result.files.single.name.toLowerCase();
    List<List<dynamic>> rows;

    if (fileName.endsWith('.xlsx')) {
      try {
        rows = XlsxService.parseXlsx(bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to parse Excel file: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    } else {
      final csvString = utf8.decode(bytes, allowMalformed: true);
      try {
        rows = const CsvToListConverter(eol: '\n').convert(csvString);
      } catch (_) {
        rows = const CsvToListConverter(eol: '\r\n').convert(csvString);
      }
    }

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected file is empty.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Parse header row
    final headerRow = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final dataRows = rows.skip(1).where((r) => r.isNotEmpty).toList();

    int inserted = 0;
    int updated = 0;
    int failed = 0;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Importing Trips...'),
          content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text('Processing ${dataRows.length} rows...'),
            ]),
          ),
        );
      }),
    );

    for (final row in dataRows) {
      if (row.length < 2) continue;
      try {
        int col(String name) {
          final idx = headerRow.indexOf(name);
          return idx >= 0 ? idx : -1;
        }
        String str(String name) {
          final i = col(name);
          return i >= 0 && i < row.length ? row[i].toString().trim() : '';
        }
        double dbl(String name, [double def = 0]) => double.tryParse(str(name)) ?? def;
        int intVal(String name, [int def = 0]) => int.tryParse(str(name)) ?? def;

        final rowId = str('id');
        final tripData = {
          'title': str('title').toUpperCase(),
          'location': str('location'),
          'category': str('category').isEmpty ? 'Yatra' : str('category'),
          'duration': str('duration'),
          'base_price': dbl('base_price'),
          'discount_percent': dbl('discount_percent'),
          'reward_points': intVal('reward_points'),
          'difficulty': str('difficulty').isEmpty ? 'Moderate' : str('difficulty'),
          'altitude': str('altitude'),
          'best_months': str('best_months').isEmpty ? 'Mar-Jun, Sep-Dec' : str('best_months'),
          'peak_elevation': str('peak_elevation').isEmpty ? 'N/A' : str('peak_elevation'),
          'trail_type': str('trail_type').isEmpty ? 'Mixed' : str('trail_type'),
          'start_point': str('start_point'),
          'package_type': str('package_type').isEmpty ? 'Standard' : str('package_type'),
          'rating': dbl('rating', 5.0),
          'total_distance': str('total_distance'),
          'image_url': str('image_url'),
          'description': str('description'),
        };

        if (rowId.isNotEmpty && rowId != 'null') {
          // Update existing trip
          await _client.from('trips').update(tripData).eq('id', rowId);
          updated++;
        } else {
          // Insert new trip
          tripData['created_at'] = DateTime.now().toIso8601String();
          await _client.from('trips').insert(tripData);
          inserted++;
        }
      } catch (e) {
        failed++;
        debugPrint('Import row error: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context); // dismiss loading dialog
      _fetchTrips();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import Complete ✅'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _resultRow(Icons.add_circle_outline, Colors.green, '$inserted new trips inserted'),
            _resultRow(Icons.edit_outlined, Colors.blue, '$updated trips updated'),
            if (failed > 0) _resultRow(Icons.error_outline, Colors.red, '$failed rows failed'),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
              child: const Text('DONE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  Widget _resultRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BULK MANAGEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)),
              const SizedBox(height: 16),
              // ── EXPORT options ──
              const Text('EXPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _menuTile(
                icon: Icons.table_chart,
                color: Colors.green.shade700,
                title: 'Export to Excel (.xlsx)',
                subtitle: '${_trips.length} trips — opens directly in Microsoft Excel & Google Sheets with bold headers',
                onTap: () { Navigator.pop(context); _exportXlsx(); },
              ),
              const SizedBox(height: 10),
              _menuTile(
                icon: Icons.download_outlined,
                color: Colors.teal,
                title: 'Export to CSV (.csv)',
                subtitle: '${_trips.length} trips — lightweight text format, universal compatibility',
                onTap: () { Navigator.pop(context); _exportCsv(); },
              ),
              const SizedBox(height: 16),
              // ── IMPORT options ──
              const Text('IMPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _menuTile(
                icon: Icons.upload_file_outlined,
                color: Colors.blue,
                title: 'Import Trips from CSV',
                subtitle: 'Pick a .csv file — rows with existing ID are updated, new rows are inserted',
                onTap: () { Navigator.pop(context); _importCsv(); },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Tip: Export first to get the correct column format. Edit in Excel/Sheets, then import back.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                  )),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _menuTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _actionChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredTrips = _trips.where((t) {
      final matchesSearch =
          (t['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t['location'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || t['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('TRIP INVENTORY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
        backgroundColor: isDark ? const Color(0xFF18181B) : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Clearly labeled Import/Export button
          TextButton.icon(
            onPressed: _showImportExportMenu,
            icon: const Icon(Icons.table_chart, color: Colors.white, size: 18),
            label: const Text('Import / Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          // Add new trip
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add New Trip',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const EditTripScreen()),
            ).then((v) { if (v == true) _fetchTrips(); }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF18181B) : Theme.of(context).primaryColor,
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search trips...',
                hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _selectedCategory == c ? Colors.white : (isDark ? Colors.grey : Colors.grey[600]))),
                  selected: _selectedCategory == c,
                  onSelected: (s) => setState(() => _selectedCategory = c),
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              )).toList(),
            ),
          ),
          // ── Bulk action strip (always visible) ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _actionChip(
                  icon: Icons.table_chart,
                  label: 'Export Excel',
                  color: Colors.green.shade700,
                  onTap: _exportXlsx,
                ),
                const SizedBox(width: 8),
                _actionChip(
                  icon: Icons.download_outlined,
                  label: 'Export CSV',
                  color: Colors.teal,
                  onTap: _exportCsv,
                ),
                const SizedBox(width: 8),
                _actionChip(
                  icon: Icons.upload_file_outlined,
                  label: 'Import CSV',
                  color: Colors.blue,
                  onTap: _importCsv,
                ),
              ],
            ),
          ),
          // Trip list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTrips.isEmpty
                    ? Center(child: Text('No trips found.', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTrips.length,
                        itemBuilder: (context, index) {
                          final trip = filteredTrips[index];
                          final hasImage = trip['image_url'] != null && trip['image_url'].toString().isNotEmpty;
                          final rewardPts = trip['reward_points'] ?? 0;

                          return FadeInUp(
                            delay: Duration(milliseconds: index * 50),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: hasImage
                                        ? Image.network(trip['image_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.terrain, color: Colors.grey, size: 24))
                                        : const Icon(Icons.terrain, color: Colors.grey, size: 24),
                                  ),
                                ),
                                title: Text(trip['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('${trip['location']} • ₹${trip['base_price']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(trip['category']?.toUpperCase() ?? 'ADVENTURE', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
                                      ),
                                      if (rewardPts > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 9),
                                            const SizedBox(width: 2),
                                            Text('$rewardPts pts', style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ]),
                                        ),
                                      ],
                                    ]),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 22, color: Colors.blueAccent),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (c) => EditTripScreen(trip: Trip.fromJson(trip))),
                                      ).then((v) { if (v == true) _fetchTrips(); }),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent),
                                      onPressed: () => _deleteTrip(trip['id'].toString()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
