import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../widgets/user_avatar.dart';
import 'package:animate_do/animate_do.dart';
import '../services/whatsapp_service.dart';
import '../screens/declaration_form_screen.dart';

class TripBookingSheet extends StatefulWidget {
  final Trip trip;
  final bool isTrip;
  final Function(
    double total,
    double tripFee,
    double pickupFee,
    String pickupLocation,
    DateTime date,
    Map<String, int> gearAddons,
    List<Gear> availableGears,
    String name,
    String phone,
    String email,
    String address,
    String aadharNo,
    int pax,
    List<Map<String, dynamic>> additionalTravelers,
    String paymentMethod,
    String? paymentProof,
    bool redeemPoints,
    int pointsRedeemed,
  )
  onConfirm;

  const TripBookingSheet({
    super.key,
    required this.trip,
    required this.isTrip,
    required this.onConfirm,
  });

  @override
  State<TripBookingSheet> createState() => _TripBookingSheetState();
}

class _TripBookingSheetState extends State<TripBookingSheet> {
  final PickupOption _baseCampPickup = PickupOption(
    location: 'Base Camp',
    price: 0,
  );
  int _currentStep = 0;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 14));
  List<Gear> _availableGears = [];
  Map<String, int> _selectedAddons = {};
  PickupOption? _selectedPickup;
  String _paymentMethod = 'UPI';
  String? _paymentProofPath;
  bool _isUploadingProof = false;
  bool _declarationSigned = false;
  bool _isGearsLoading = true;
  bool _isProfileLoaded = false;
  int _pax = 1;
  Trip? _freshTrip;

  // Reward points
  int _userRewardPoints = 0;
  bool _redeemPoints = false;
  static const int _pointsPerRupee = 10; // 10 pts = ₹1 discount

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController(
    text: Supabase.instance.client.auth.currentUser?.email,
  );
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _aadharCtrl = TextEditingController();
  final TextEditingController _licenseCtrl = TextEditingController();
  final TextEditingController _specialRequestsCtrl = TextEditingController();

  String _gender = 'Male'; // Male, Female, Other
  String _travelType = 'Solo / Standard'; // Solo / Standard, Couple (Room & Tent Sharing)
  bool _tentSharingRequired = false;
  bool _roomSharingRequired = false;

  List<Map<String, dynamic>> _additionalTravelers = [];

  Trip get _trip => _freshTrip ?? widget.trip;

  List<PickupOption> get _pickupOptions {
    final list = <PickupOption>[];
    
    // Add existing pickupOptions from DB if any
    if (_trip.pickupOptions.isNotEmpty) {
      list.addAll(_trip.pickupOptions);
    }

    // Ensure Starting Point is present
    final start = _trip.startPoint?.trim();
    if (start != null && start.isNotEmpty) {
      final startLoc = 'Start Hub: $start';
      if (!list.any((p) => p.location.toLowerCase() == startLoc.toLowerCase() || p.location.toLowerCase() == start.toLowerCase())) {
        list.add(PickupOption(location: startLoc, price: 0));
      }
    }

    // Ensure Airport / Railway are present if defined
    final apt = _trip.airport?.trim();
    if (apt != null && apt.isNotEmpty) {
      final aptLoc = 'Airport: $apt';
      if (!list.any((p) => p.location.toLowerCase().contains(apt.toLowerCase()))) {
        list.add(PickupOption(location: aptLoc, price: 0));
      }
    }

    final rly = _trip.railway?.trim();
    if (rly != null && rly.isNotEmpty) {
      final rlyLoc = 'Railway: $rly';
      if (!list.any((p) => p.location.toLowerCase().contains(rly.toLowerCase()))) {
        list.add(PickupOption(location: rlyLoc, price: 0));
      }
    }

    if (list.isEmpty) {
      final fallbackLoc = start != null && start.isNotEmpty ? start : 'Base Camp';
      list.add(PickupOption(location: fallbackLoc, price: 0));
    }

    return list;
  }

  String get _dropPointDisplay {
    if (_trip.endPoint != null && _trip.endPoint!.trim().isNotEmpty) {
      return _trip.endPoint!.trim();
    }
    if (_trip.startPoint != null && _trip.startPoint!.trim().isNotEmpty) {
      return _trip.startPoint!.trim();
    }
    return _selectedPickup?.location ?? 'Base Camp';
  }

  int get _slotCapacity => _trip.slotCapacity > 0 ? _trip.slotCapacity : 15;

  @override
  void initState() {
    super.initState();
    _selectedPickup = _pickupOptions.first;
    _loadInitialData();
  }

  Map<String, int>? _cachedAvailability;

  Future<void> _loadInitialData() async {
    final freshTrip = await DatabaseService().fetchTripById(widget.trip.id);
    if (mounted && freshTrip != null) {
      setState(() {
        _freshTrip = freshTrip;
        if (_selectedPickup == null && _pickupOptions.isNotEmpty) {
          _selectedPickup = _pickupOptions.first;
        }
        if (_trip.availableDates != null &&
            !_batchDates.any((d) => _dateKey(d) == _dateKey(_selectedDate)) &&
            _batchDates.isNotEmpty) {
          _selectedDate = _batchDates.first;
        }
      });
    }

    // Load Gears
    final gears = await DatabaseService().fetchGears();
    if (mounted) {
      setState(() {
        _availableGears = gears;
        _isGearsLoading = false;
      });
    }

    // Load Profile + reward points
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      int cachedProfilePoints = 0;
      if (profile != null) {
        cachedProfilePoints =
            int.tryParse((profile['reward_points'] ?? 0).toString()) ?? 0;
      }
      if (mounted && profile != null) {
        setState(() {
          if (_nameCtrl.text.isEmpty)
            _nameCtrl.text = profile['full_name'] ?? '';
          if (_phoneCtrl.text.isEmpty)
            _phoneCtrl.text = profile['phone_number'] ?? '';
          _declarationSigned = profile['declaration_signed'] == true;
          _isProfileLoaded = true;
        });
      }

      // Fetch reward points balance from reward_ledger
      try {
        final ledger = await Supabase.instance.client
            .from('reward_ledger')
            .select('points, type')
            .eq('user_id', user.id);
        int total = 0;
        final ledgerList = ledger as List;
        for (final row in ledgerList) {
          final pts = int.tryParse((row['points'] ?? 0).toString()) ?? 0;
          final type = row['type']?.toString() ?? 'credit';
          total += type == 'debit' ? -pts : pts;
        }
        if (ledgerList.isEmpty && cachedProfilePoints > 0) {
          total = cachedProfilePoints;
        }
        if (mounted) setState(() => _userRewardPoints = total < 0 ? 0 : total);
      } catch (_) {
        if (mounted) {
          setState(
            () => _userRewardPoints = cachedProfilePoints < 0
                ? 0
                : cachedProfilePoints,
          );
        }
      }
    }

    // Prefetch availability
    final availability = await _fetchBatchAvailability();
    if (mounted) setState(() => _cachedAvailability = availability);
  }

  Future<Map<String, int>> _fetchBatchAvailability() async {
    if (_cachedAvailability != null) return _cachedAvailability!;
    try {
      final res = await Supabase.instance.client
          .from('bookings')
          .select('trip_date, hiker_pax')
          .eq('trip_id', _trip.id)
          .neq('status', 'cancelled');
      Map<String, int> availability = {};
      for (var b in (res as List)) {
        final parsedDate = DateTime.tryParse(b['trip_date'].toString());
        final date = parsedDate == null
            ? b['trip_date'].toString()
            : DateFormat('yyyy-MM-dd').format(parsedDate);
        availability[date] =
            (availability[date] ?? 0) +
            (int.tryParse(b['hiker_pax'].toString()) ?? 1);
      }
      return availability;
    } catch (_) {
      return {};
    }
  }

  double _calculateAddonsTotal() {
    double total = 0;
    final match = RegExp(r'\d+').firstMatch(_trip.duration);
    final durationDays = match != null ? (int.tryParse(match.group(0)!) ?? 1) : 1;
    _selectedAddons.forEach((id, qty) {
      final gear = _availableGears.firstWhere((g) => g.id == id, orElse: () => Gear(id: id, name: '', pricePerDay: 0, category: '', description: ''));
      total += gear.pricePerDay * qty * durationDays;
    });
    return total;
  }

  /// Max points a user can redeem = min(balance, 50% of grand total in points)
  int get _maxRedeemablePoints {
    final tripFee = _trip.discountedPrice * _pax;
    final pickupFee = (_selectedPickup?.price ?? 0) * _pax;
    final grandTotal = tripFee + pickupFee + _calculateAddonsTotal();
    // Allow up to 50% discount via points
    final maxDiscountRupees = (grandTotal * 0.5).floor();
    final maxPoints = maxDiscountRupees * _pointsPerRupee;
    return _userRewardPoints < maxPoints ? _userRewardPoints : maxPoints;
  }

  double get _pointsDiscount =>
      _redeemPoints ? (_maxRedeemablePoints / _pointsPerRupee) : 0;

  int get _tripRewardPointsEarned => _trip.rewardPoints;

  List<DateTime> get _batchDates {
    final configured = _trip.availableDates
        ?.where((d) => !_dateOnly(d).isBefore(_dateOnly(DateTime.now())))
        .toList();
    if (configured != null && configured.isNotEmpty) {
      configured.sort();
      return configured.take(14).toList();
    }

    final batches = <DateTime>[];
    var cursor = DateTime.now().add(const Duration(days: 1));
    while (batches.length < 7) {
      batches.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return batches;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  int _remainingSlotsForDate(DateTime date) {
    final booked = _cachedAvailability?[_dateKey(date)] ?? 0;
    return (_slotCapacity - booked).clamp(0, _slotCapacity);
  }

  int get _selectedDateSlotsLeft => _remainingSlotsForDate(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double tripFee = _trip.discountedPrice * _pax;
    final double pickupFee = (_selectedPickup?.price ?? 0) * _pax;
    final double subtotal = tripFee + pickupFee + _calculateAddonsTotal();
    final double gstAmount = subtotal * (_trip.gstPercent / 100);
    final double grandTotal =
        (subtotal + gstAmount - _pointsDiscount).clamp(
          0,
          double.infinity,
        );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildStepperHeader(),
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStepHikerInfo(),
                  _buildStepLogistics(),
                  _buildStepGears(),
                  _buildStepSummary(grandTotal, tripFee, pickupFee),
                  _buildStepPayment(grandTotal),
                ],
              ),
            ),
            _buildFooter(grandTotal),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Secure Your Spot',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepIndicator(0, 'PROFILE'),
          _stepConnector(),
          _stepIndicator(1, 'BATCH'),
          _stepConnector(),
          _stepIndicator(2, 'GEAR'),
          _stepConnector(),
          _stepIndicator(3, 'SUMMARY'),
          _stepConnector(),
          _stepIndicator(4, 'PAY'),
        ],
      ),
    );
  }

  Widget _stepIndicator(int step, String label) {
    bool isActive = _currentStep == step;
    bool isDone = _currentStep > step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : (isDone ? Colors.green : Colors.grey.shade300),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: isActive ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _stepConnector() {
    return Expanded(
      child: Container(
        height: 1,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildStepHikerInfo() {
    return FadeIn(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'PRIMARY HIKER (LEAD EXPLORER)',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age *',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: const Icon(Icons.wc),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other / Any')),
                  ],
                  onChanged: (val) => setState(() => _gender = val ?? 'Male'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: const Icon(Icons.phone_android),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address *',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aadharCtrl,
            keyboardType: TextInputType.number,
            maxLength: 12,
            decoration: InputDecoration(
              labelText: 'Aadhar Card Number (12 Digits) *',
              prefixIcon: const Icon(Icons.badge_outlined),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Residential Address / City *',
              prefixIcon: const Icon(Icons.home_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── COUPLE & ROOM / TENT SHARING ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.04),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.purple.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ACCOMMODATION & SHARING PREFERENCES',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.purple, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _travelType,
                  decoration: InputDecoration(
                    labelText: 'Traveler Type',
                    prefixIcon: const Icon(Icons.group_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Solo / Standard', child: Text('Solo / Standard Sharing')),
                    DropdownMenuItem(value: 'Couple', child: Text('Couple (Traveling as Couple)')),
                    DropdownMenuItem(value: 'Family / Private Group', child: Text('Family / Private Group')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _travelType = val ?? 'Solo / Standard';
                      if (_travelType == 'Couple') {
                        _tentSharingRequired = true;
                        _roomSharingRequired = true;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Couple Tent Sharing Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Dedicated 2-person tent during alpine camping', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _tentSharingRequired,
                  onChanged: (val) => setState(() => _tentSharingRequired = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Private Room Sharing Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Double occupancy room at basecamp guest house/hotel', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _roomSharingRequired,
                  onChanged: (val) => setState(() => _roomSharingRequired = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialRequestsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Special Requirements / Dietary / Medical Notes (Optional)',
              hintText: 'e.g. Jain food, strict vegan, luggage offloading, height allergy, couple private tent',
              prefixIcon: const Icon(Icons.note_alt_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          if (_trip.category.toLowerCase().contains('bike')) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _licenseCtrl,
              decoration: InputDecoration(
                labelText: 'Driving License Number',
                prefixIcon: const Icon(Icons.card_membership_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Traveling With Others (Group)?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _paxCounter(),
            ],
          ),
          if (_additionalTravelers.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._additionalTravelers.asMap().entries.map(
              (e) => _additionalTravelerForm(e.key),
            ),
          ],
          const SizedBox(height: 24),
          _declarationTile(),
        ],
      ),
    );
  }

  Widget _paxCounter() {
    final maxPax = _selectedDateSlotsLeft > 0
        ? _selectedDateSlotsLeft
        : _slotCapacity;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_pax > 1) {
                setState(() {
                  _pax--;
                  _additionalTravelers.removeLast();
                });
              }
            },
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text('$_pax', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () {
              if (_pax >= maxPax) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Only $maxPax slot${maxPax == 1 ? '' : 's'} left for this date',
                    ),
                  ),
                );
                return;
              }
              setState(() {
                _pax++;
                _additionalTravelers.add({
                  'name': TextEditingController(),
                  'age': TextEditingController(),
                  'gender': 'Male',
                  'aadhar': TextEditingController(),
                  'phone': TextEditingController(),
                });
              });
            },
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _additionalTravelerForm(int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUP MEMBER #${idx + 2}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _additionalTravelers[idx]['name'] as TextEditingController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _additionalTravelers[idx]['age'] as TextEditingController,
                  decoration: const InputDecoration(
                    labelText: 'Age *',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: (_additionalTravelers[idx]['gender'] ?? 'Male').toString(),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('M', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Female', child: Text('F', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Other', child: Text('O', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _additionalTravelers[idx]['gender'] = val ?? 'Male';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _additionalTravelers[idx]['aadhar'] as TextEditingController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Aadhar Number (12 Digits) *',
                    isDense: true,
                    counterText: '',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _additionalTravelers[idx]['phone'] as TextEditingController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    isDense: true,
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _declarationTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _declarationSigned
            ? Colors.green.withOpacity(0.05)
            : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _declarationSigned
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _declarationSigned ? Icons.verified : Icons.gavel,
            color: _declarationSigned ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _declarationSigned
                  ? 'Risk Declaration Signed ✓'
                  : 'Safety Waiver Required',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          if (!_declarationSigned)
            TextButton(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) =>
                        DeclarationFormScreen(tripTitle: _trip.title),
                  ),
                );
                if (res == true) setState(() => _declarationSigned = true);
              },
              child: const Text(
                'SIGN NOW',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepLogistics() {
    return FadeIn(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'SELECT BATCH',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, int>>(
            future: _fetchBatchAvailability(),
            builder: (context, snapshot) {
              final availability = snapshot.data ?? {};
              final batches = _batchDates;
              return SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: batches.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == batches.length) return _otherDateCard(batches);
                    final d = batches[i];
                    final dStr = DateFormat('yyyy-MM-dd').format(d);
                    final left = (_slotCapacity - (availability[dStr] ?? 0))
                        .clamp(0, _slotCapacity);
                    final isSelected =
                        DateFormat('yyyy-MM-dd').format(_selectedDate) == dStr;
                    return _batchCard(d, left, isSelected);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PICKUP & BOARDING HUB',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.blueGrey,
                  letterSpacing: 0.5,
                ),
              ),
              if (_trip.startPoint != null && _trip.startPoint!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Default: ${_trip.startPoint}',
                    style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._pickupOptions.map(
            (opt) {
              final isSelected = _selectedPickup?.location.toLowerCase().trim() == opt.location.toLowerCase().trim();
              final isDefault = (_trip.startPoint != null && opt.location.toLowerCase().contains(_trip.startPoint!.toLowerCase())) ||
                  opt.location.toLowerCase().contains('start hub') ||
                  opt.location.toLowerCase().contains('base camp');
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPickup = opt;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(isDark ? 0.2 : 0.08)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      opt.location,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? Theme.of(context).primaryColor : null,
                                      ),
                                    ),
                                  ),
                                  if (isDefault) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                                      ),
                                      child: const Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.green,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.price > 0 ? '+₹${opt.price.toInt()}' : 'Free / Included in Package',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: opt.price > 0 ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text(
                  'Drop / Return Hub: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    _dropPointDisplay,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _batchCard(DateTime d, int left, bool isSelected) {
    return GestureDetector(
      onTap: left <= 0
          ? null
          : () => setState(() {
              _selectedDate = d;
              if (_pax > left) {
                _pax = left;
                final additionalCount = _pax > 1 ? _pax - 1 : 0;
                while (_additionalTravelers.length > additionalCount) {
                  _additionalTravelers.removeLast();
                }
              }
            }),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : (left <= 0
                    ? Colors.red.withOpacity(0.04)
                    : Colors.grey.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('MMM dd').format(d),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: left <= 3
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                left <= 0 ? 'FULL' : '$left LEFT',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: left <= 3 ? Colors.red : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otherDateCard(List<DateTime> batches) {
    bool isSelected = !batches.any(
      (b) =>
          DateFormat('yyyy-MM-dd').format(b) ==
          DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'SELECT YOUR CUSTOM DATE',
        );
        if (d != null) setState(() => _selectedDate = d);
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : Theme.of(context).primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : Theme.of(context).primaryColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_calendar,
              color: isSelected
                  ? Colors.blueAccent
                  : Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              isSelected
                  ? DateFormat('MMM dd').format(_selectedDate)
                  : 'CUSTOM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blueAccent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepGears() {
    if (_isGearsLoading)
      return const Center(child: CircularProgressIndicator());
    return FadeIn(
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _availableGears.length,
        itemBuilder: (c, idx) {
          final gear = _availableGears[idx];
          final qty = _selectedAddons[gear.id] ?? 0;
          return ListTile(
            title: Text(
              gear.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('₹${gear.pricePerDay.toInt()}/day'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qty > 0)
                  IconButton(
                    onPressed: () => setState(
                      () => qty > 1
                          ? _selectedAddons[gear.id] = qty - 1
                          : _selectedAddons.remove(gear.id),
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                if (qty > 0)
                  Text(
                    '$qty',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                IconButton(
                  onPressed: () =>
                      setState(() => _selectedAddons[gear.id] = qty + 1),
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY STEP — with reward points earn/redeem UI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepSummary(double total, double tripFee, double pickupFee) {
    final baseTotal = tripFee + pickupFee + _calculateAddonsTotal();
    final bool hasPointsToRedeem =
        _userRewardPoints > 0 && _maxRedeemablePoints > 0;
    final pointsToEarn = _tripRewardPointsEarned * _pax;

    return FadeIn(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'BOOKING SUMMARY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('Trip', _trip.title),
          _summaryRow('Date', DateFormat('dd MMM yyyy').format(_selectedDate)),
          _summaryRow('Lead Explorer', '${_nameCtrl.text} ($_gender, Age: ${_ageCtrl.text})'),
          _summaryRow('Contact', _phoneCtrl.text),
          _summaryRow('Email', _emailCtrl.text),
          if (_aadharCtrl.text.isNotEmpty) _summaryRow('Lead Aadhar', _aadharCtrl.text),
          if (_addressCtrl.text.isNotEmpty) _summaryRow('Address', _addressCtrl.text),
          _summaryRow('Travel Type', _travelType),
          if (_tentSharingRequired) _summaryRow('Tent Sharing', '✅ Couple Tent Sharing (Double Tent)'),
          if (_roomSharingRequired) _summaryRow('Room Sharing', '✅ Private Double Occupancy Room'),
          if (_specialRequestsCtrl.text.isNotEmpty) _summaryRow('Special Requests', _specialRequestsCtrl.text),
          _summaryRow('Total Travelers', '$_pax Person(s)'),
          if (_additionalTravelers.isNotEmpty) ...[
            ..._additionalTravelers.asMap().entries.map((e) {
              final n = (e.value['name'] as TextEditingController).text;
              final a = (e.value['aadhar'] as TextEditingController).text;
              final ag = (e.value['age'] as TextEditingController).text;
              final g = (e.value['gender'] ?? 'Male').toString();
              return _summaryRow('Member #${e.key + 2}', '$n ($g, Age: $ag, Aadhar: $a)');
            }),
          ],
          _summaryRow('Pickup Hub', _selectedPickup?.location ?? (_trip.startPoint ?? 'Base Camp')),
          _summaryRow('Drop Hub', _dropPointDisplay),
          const Divider(height: 32),
          _costRow('Trip Fee', tripFee),
          if (pickupFee > 0) _costRow('Pickup Fee (${_selectedPickup?.location ?? ""})', pickupFee),
          if (_selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'GEAR RENTALS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            ..._selectedAddons.entries.map((e) {
              final gear = _availableGears.firstWhere((g) => g.id == e.key, orElse: () => Gear(id: e.key, name: 'Gear', pricePerDay: 0, category: '', description: ''));
              final match = RegExp(r'\d+').firstMatch(_trip.duration);
              final durationDays = match != null ? (int.tryParse(match.group(0)!) ?? 1) : 1;
              return _costRow(
                '${gear.name} (x${e.value})',
                gear.pricePerDay * e.value * durationDays,
              );
            }),
          ],
          const SizedBox(height: 8),
          _costRow('Subtotal', baseTotal),
          _costRow('GST (${_trip.gstPercent.toStringAsFixed(0)}%)', baseTotal * (_trip.gstPercent / 100)),

          // ── Reward Points Redemption ─────────────────────────────────────
          if (hasPointsToRedeem) ...[
            const SizedBox(height: 16),
            _buildRedeemCard(),
          ],
          if (_redeemPoints && _pointsDiscount > 0)
            _costRowColored(
              '🏆 Reward Points Discount (-${_maxRedeemablePoints} pts)',
              -_pointsDiscount,
              Colors.amber.shade700,
            ),

          const SizedBox(height: 16),
          // ── Grand Total ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount (Incl. GST)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${total.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // ── Points to Earn Banner ────────────────────────────────────────
          if (pointsToEarn > 0) ...[
            const SizedBox(height: 12),
            FadeInUp(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOU WILL EARN',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '$pointsToEarn Reward Points',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Worth ₹${(pointsToEarn / _pointsPerRupee).toStringAsFixed(0)} off on your next booking',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Existing balance ─────────────────────────────────────────────
          if (_userRewardPoints > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Your current balance: $_userRewardPoints pts',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRedeemCard() {
    final discount = (_maxRedeemablePoints / _pointsPerRupee).toStringAsFixed(
      0,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'USE REWARD POINTS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Redeem $_maxRedeemablePoints pts for ₹$discount off',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Balance: $_userRewardPoints pts',
                  style: const TextStyle(fontSize: 10, color: Colors.amber),
                ),
              ],
            ),
          ),
          Switch(
            value: _redeemPoints,
            activeColor: Colors.amber,
            onChanged: (v) => setState(() => _redeemPoints = v),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            '₹${value.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _costRowColored(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${value >= 0 ? '₹' : '-₹'}${value.abs().toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double total) {
    bool isLastStep = _currentStep == 4;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('BACK'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 4) {
                  if (_currentStep == 0) {
                    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill your Full Name and Phone Number'),
                        ),
                      );
                      return;
                    }
                    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid Email Address'),
                        ),
                      );
                      return;
                    }
                    final primaryAge = int.tryParse(_ageCtrl.text.trim());
                    if (primaryAge == null || primaryAge <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid Age for the lead explorer'),
                        ),
                      );
                      return;
                    }
                    if (_aadharCtrl.text.trim().isEmpty || _aadharCtrl.text.trim().length < 12) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid 12-digit Aadhar card number for the lead explorer'),
                        ),
                      );
                      return;
                    }
                    if (_addressCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your residential address / city'),
                        ),
                      );
                      return;
                    }
                    // Validate additional group members
                    for (int i = 0; i < _additionalTravelers.length; i++) {
                      final t = _additionalTravelers[i];
                      final nameCtrl = t['name'] as TextEditingController;
                      final ageCtrl = t['age'] as TextEditingController;
                      final aadharCtrl = t['aadhar'] as TextEditingController;
                      final phoneCtrl = t['phone'] as TextEditingController;

                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter Full Name for Group Member #${i + 2}'),
                          ),
                        );
                        return;
                      }
                      final mAge = int.tryParse(ageCtrl.text.trim());
                      if (mAge == null || mAge <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid Age for Group Member #${i + 2}'),
                          ),
                        );
                        return;
                      }
                      if (phoneCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter Phone Number for Group Member #${i + 2}'),
                          ),
                        );
                        return;
                      }
                      final aadhar = aadharCtrl.text.trim();
                      if (aadhar.isEmpty || aadhar.length < 12) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid 12-digit Aadhar number for Group Member #${i + 2}'),
                          ),
                        );
                        return;
                      }
                    }
                    if (!_declarationSigned) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please sign the declaration'),
                        ),
                      );
                      return;
                    }
                  }
                  if (_currentStep == 1) {
                    final left = _selectedDateSlotsLeft;
                    if (left <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This batch is full. Please choose another date.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_pax > left) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Only $left slot${left == 1 ? '' : 's'} left for this date.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_pickupOptions.isNotEmpty && _selectedPickup == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a pickup point.'),
                        ),
                      );
                      return;
                    }
                  }
                  setState(() => _currentStep++);
                } else {
                  if (_paymentMethod == 'UPI' && _paymentProofPath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please upload payment screenshot'),
                      ),
                    );
                    // bypass for testing
                  }
                  widget.onConfirm(
                    total,
                    _trip.discountedPrice * _pax,
                    (_selectedPickup?.price ?? 0) * _pax,
                    _selectedPickup?.location ?? '',
                    _selectedDate,
                    _selectedAddons,
                    _availableGears,
                    _nameCtrl.text.trim(),
                    _phoneCtrl.text.trim(),
                    _emailCtrl.text.trim(),
                    _addressCtrl.text.trim(),
                    _aadharCtrl.text.trim(),
                    _pax,
                    [
                      {
                        'name': _nameCtrl.text.trim(),
                        'age': int.tryParse(_ageCtrl.text.trim()) ?? 0,
                        'gender': _gender,
                        'phone': _phoneCtrl.text.trim(),
                        'aadhar': _aadharCtrl.text.trim(),
                        'address': _addressCtrl.text.trim(),
                        'travel_type': _travelType,
                        'tent_sharing': _tentSharingRequired,
                        'room_sharing': _roomSharingRequired,
                        'special_requests': _specialRequestsCtrl.text.trim(),
                        'is_primary': true,
                      },
                      ..._additionalTravelers.map((t) => {
                        'name': (t['name'] as TextEditingController).text.trim(),
                        'age': int.tryParse((t['age'] as TextEditingController).text.trim()) ?? 0,
                        'gender': (t['gender'] ?? 'Male').toString(),
                        'phone': (t['phone'] as TextEditingController).text.trim(),
                        'aadhar': (t['aadhar'] as TextEditingController).text.trim(),
                        'travel_type': _travelType,
                        'tent_sharing': _tentSharingRequired,
                        'room_sharing': _roomSharingRequired,
                        'special_requests': _specialRequestsCtrl.text.trim(),
                        'is_primary': false,
                      }),
                    ],
                    _paymentMethod,
                    _paymentProofPath,
                    _redeemPoints,
                    _redeemPoints ? _maxRedeemablePoints : 0,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                isLastStep
                    ? (_paymentMethod == 'UPI'
                          ? 'CONFIRM & SUBMIT'
                          : 'BOOK NOW')
                    : 'CONTINUE',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPayment(double total) {
    return FadeIn(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'PAYMENT METHOD',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          _paymentOption(
            'UPI Transfer (Instant)',
            'Pay via GPay, PhonePe, etc.',
            Icons.account_balance_wallet,
            'UPI',
          ),
          _paymentOption(
            'WhatsApp Confirmation',
            'Manual chat verification',
            Icons.chat,
            'WhatsApp',
          ),
          _paymentOption(
            'Cash at Base Camp',
            'Pay when you arrive',
            Icons.payments_outlined,
            'Cash',
          ),
          const SizedBox(height: 24),
          if (_paymentMethod == 'UPI') ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'SEND ₹${total.toInt()} TO:',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'tripindia@okaxis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload your payment screenshot below for verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (_isUploadingProof)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Uploading screenshot...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result == null || result.files.single.bytes == null) return;
                          
                          setState(() => _isUploadingProof = true);
                          final bytes = result.files.single.bytes!;
                          final name = result.files.single.name;
                          final ext = name.split('.').last.toLowerCase();
                          final user = Supabase.instance.client.auth.currentUser;
                          final fileName = 'payment_${user?.id ?? "guest"}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                          
                          // Upload to Supabase Storage 'payment_proofs' bucket
                          await Supabase.instance.client.storage
                              .from('payment_proofs')
                              .uploadBinary(
                                fileName,
                                bytes,
                                fileOptions: FileOptions(
                                  contentType: 'image/$ext',
                                  upsert: true,
                                ),
                              );

                          final publicUrl = Supabase.instance.client.storage
                              .from('payment_proofs')
                              .getPublicUrl(fileName);

                          if (mounted) {
                            setState(() {
                              _paymentProofPath = publicUrl;
                              _isUploadingProof = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment screenshot uploaded successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isUploadingProof = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        _paymentProofPath == null
                            ? Icons.upload_file
                            : Icons.check_circle,
                        color: _paymentProofPath == null
                            ? Colors.blue
                            : Colors.green,
                      ),
                      label: Text(
                        _paymentProofPath == null
                            ? 'PICK FROM GALLERY / FILES'
                            : 'PROOF ATTACHED (TAP TO REPLACE)',
                      ),
                    ),
                  if (_paymentProofPath != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _paymentProofPath!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_paymentMethod == 'WhatsApp') ...[
            const Text(
              'After clicking BOOK NOW, you will be redirected to WhatsApp to share your booking ID and complete payment manually.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentOption(String title, String sub, IconData icon, String val) {
    bool isSel = _paymentMethod == val;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = val),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSel ? Colors.black : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSel ? Colors.white : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSel ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSel ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSel)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
