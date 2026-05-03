import 'package:flutter/material.dart';
import 'admin_bookings_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'payment_ledger_screen.dart';

import 'admin_category_management_screen.dart';

class AdminManagementHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const AdminManagementHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminManagementHubScreen> createState() => _AdminManagementHubScreenState();
}

class _AdminManagementHubScreenState extends State<AdminManagementHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management Hub TRIP INDIA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.book_online, size: 18), text: 'TRIPS'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'RENTALS'),
            Tab(icon: Icon(Icons.wallet, size: 18), text: 'WALLETS'),
            Tab(icon: Icon(Icons.category, size: 18), text: 'CATEGORIES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminBookingsScreen(),
          AdminRentalTrackingScreen(),
          PaymentLedgerScreen(),
          AdminCategoryManagementScreen(),
        ],
      ),
    );
  }
}
