import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class PolicyHandbookScreen extends StatelessWidget {
  const PolicyHandbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('EMPLOYEE HANDBOOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildPolicyCard('Safety Protocols', 'Mandatory safety checklist for all guides during high-altitude trips.', Icons.security, Colors.blue, context),
          _buildPolicyCard('Reporting Standards', 'Format and frequency requirements for situational reports from field groups.', Icons.assignment, Colors.orange, context),
          _buildPolicyCard('Code of Conduct', 'Professional ethics and behavioral standards during user-facing trips.', Icons.groups, Colors.teal, context),
          _buildPolicyCard('Asset Care', 'Guidelines for preservation and maintenance of details gear and trip assets.', Icons.inventory_2, Colors.purple, context),
          _buildPolicyCard('Emergency Response', 'Reporting hierarchy and protocols for medical or situational emergencies.', Icons.emergency, Colors.red, context),
          _buildPolicyCard('Settlement Guidelines', 'Payout schedules, allowances, and reimbursement claims procedures.', Icons.payments, Colors.green, context),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'REVISED OFFICIAL VERSION 2.1.0\nPROPERTY OF TRIP INDIA TRIP INDIA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(String title, String desc, IconData icon, Color color, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInRight(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          ]),
          const SizedBox(height: 16),
          Text(desc, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          TextButton(onPressed: () {}, child: Text('VIEW DETAILED INFO', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1))),
        ]),
      ),
    );
  }
}
