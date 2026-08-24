import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../services/xlsx_service.dart';
import 'edit_trip_screen.dart';

class AdminPackageManagementScreen extends StatefulWidget {
  const AdminPackageManagementScreen({super.key});

  @override
  State<AdminPackageManagementScreen> createState() => _AdminPackageManagementScreenState();
}

class _AdminPackageManagementScreenState extends State<AdminPackageManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Trip> _allTrips = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final trips = await _dbService.fetchTrips();
    if (mounted) {
      setState(() {
        _allTrips = trips;
        _isLoading = false;
      });
    }
  }

  List<Trip> get _filteredTrips {
    if (_searchQuery.isEmpty) return _allTrips;
    return _allTrips.where((t) => 
      t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      t.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      t.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _deleteTrip(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Package?'),
        content: const Text('This will permanently remove this trip package and all associated booking options.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('trips').delete().eq('id', id);
        _loadTrips();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Package deleted successfully.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Control', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Export Excel',
            onPressed: () async {
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
                // Ensure fresh trips from db
                List<Trip> tripsToExport = _allTrips;
                if (tripsToExport.isEmpty) {
                  tripsToExport = await _dbService.fetchTrips();
                }
                if (tripsToExport.isEmpty) {
                  final rawTrips = await Supabase.instance.client.from('trips').select('*, trip_packages(*), pickup_options(*)');
                  tripsToExport = (rawTrips as List).map((e) => Trip.fromJson(e)).toList();
                }

                final List<List<dynamic>> rows = [
                  [
                    'id', 'title', 'location', 'category', 'duration', 'base_price',
                    'discount_percent', 'gst_percent', 'reward_points', 'difficulty', 'altitude',
                    'best_months', 'peak_elevation', 'trail_type', 'start_point', 'end_point',
                    'airport', 'railway', 'buses_cabs', 'state', 'district',
                    'min_height', 'max_height', 'min_temp', 'max_temp', 'weather',
                    'package_type', 'rating', 'total_distance', 'slot_capacity', 'latitude', 'longitude',
                    'google_map_link', 'terms_conditions', 'cancellation_policy', 'trip_story',
                    'image_url', 'images', 'inclusions', 'exclusions', 'carry_list', 'description'
                  ]
                ];

                for (final trip in tripsToExport) {
                  rows.add([
                    trip.id,
                    trip.title,
                    trip.location,
                    trip.category,
                    trip.duration,
                    trip.basePrice,
                    trip.discountPercent,
                    trip.gstPercent,
                    trip.rewardPoints,
                    trip.difficulty,
                    trip.altitude,
                    trip.bestMonths,
                    trip.peakElevation,
                    trip.trailType,
                    trip.startPoint ?? '',
                    trip.endPoint ?? '',
                    trip.airport ?? '',
                    trip.railway ?? '',
                    trip.busesCabs ?? '',
                    trip.state ?? '',
                    trip.district ?? '',
                    trip.minHeight ?? '',
                    trip.maxHeight ?? '',
                    trip.minTemp ?? '',
                    trip.maxTemp ?? '',
                    trip.weather ?? '',
                    trip.packageType ?? '',
                    trip.rating,
                    trip.totalDistance,
                    trip.slotCapacity,
                    trip.latitude,
                    trip.longitude,
                    trip.googleMapLink ?? '',
                    trip.termsConditions ?? '',
                    trip.cancellationPolicy ?? '',
                    (trip.tripStory ?? '').replaceAll('\n', ' '),
                    trip.imageUrl,
                    trip.images.join(' | '),
                    trip.inclusions.join(' | '),
                    trip.exclusions.join(' | '),
                    trip.carryList.join(' | '),
                    trip.description.replaceAll('\n', ' '),
                  ]);
                }
                final bytes = XlsxService.buildXlsx(rows);
                final fileName = 'packages_export_${DateTime.now().millisecondsSinceEpoch}';

                if (mounted) Navigator.pop(context); // Dismiss loading

                // Offer Save vs Share prompt
                if (mounted) {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (sheetCtx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export ${tripsToExport.length} Packages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text('Choose how you want to save or share your Excel file:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.download, color: Colors.green)),
                              title: const Text('Save to Device / Custom Path', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: const Text('Choose folder destination in system file picker', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              onTap: () async {
                                Navigator.pop(sheetCtx);
                                await FileSaver.instance.saveFile(
                                  name: fileName,
                                  bytes: bytes,
                                  ext: 'xlsx',
                                  mimeType: MimeType.microsoftExcel,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('✅ Exported ${tripsToExport.length} packages successfully.'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.share, color: Colors.blue)),
                              title: const Text('Share Excel Spreadsheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: const Text('Send directly to WhatsApp, Email, Drive or AirDrop', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              onTap: () async {
                                Navigator.pop(sheetCtx);
                                final tempDir = await getTemporaryDirectory();
                                final file = File('${tempDir.path}/$fileName.xlsx');
                                await file.writeAsBytes(bytes);
                                await Share.shareXFiles([XFile(file.path)], text: 'Exported Packages (${tripsToExport.length} items)');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.white),
            tooltip: 'Import CSV / Excel',
            onPressed: () async {
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

              final headerRow = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: Card(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(), SizedBox(width: 16), Text('Upserting packages...'),
                  ]),
                ))),
              );

              try {
                final client = Supabase.instance.client;
                int count = 0;
                for (int i = 1; i < rows.length; i++) {
                  final row = rows[i];
                  if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
                  
                  final Map<String, dynamic> data = {};
                  for (int j = 0; j < headerRow.length; j++) {
                    if (j < row.length) {
                      final val = row[j];
                      final col = headerRow[j];
                      if (col == 'base_price' || col == 'discount_percent' || col == 'gst_percent' || col == 'rating' || col == 'latitude' || col == 'longitude') {
                        data[col] = num.tryParse(val.toString()) ?? 0;
                      } else if (col == 'reward_points' || col == 'slot_capacity') {
                        data[col] = int.tryParse(val.toString()) ?? 0;
                      } else if (col == 'images' || col == 'inclusions' || col == 'exclusions' || col == 'carry_list') {
                        final strVal = val.toString().trim();
                        data[col] = strVal.isEmpty ? [] : strVal.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      } else {
                        data[col] = val.toString();
                      }
                    }
                  }
                  
                  if (data['id'] != null && data['id'].toString().isNotEmpty) {
                    await client.from('trips').upsert(data);
                  } else {
                    data.remove('id');
                    await client.from('trips').insert(data);
                  }
                  count++;
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully upserted $count packages!'), backgroundColor: Colors.green));
                  _loadTrips();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () async {
            final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const EditTripScreen()));
            if (r == true) _loadTrips();
          }),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildTripList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(15)),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by title, region or category...',
                border: InputBorder.none,
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                icon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                }) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList() {
    final trips = _filteredTrips;
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No packages match your search.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final t = trips[index];
        return Container(
          key: ValueKey(t.id),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  t.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(t.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    const SizedBox(height: 4),
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${t.location} • ${t.duration}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('₹${t.basePrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue), 
                    onPressed: () async {
                      final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => EditTripScreen(trip: t)));
                      if (r == true) _loadTrips();
                    }
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteTrip(t.id)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
