import 'package:flutter/material.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Refund Policy for Trek India', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last updated: March 20, 2026', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text('Cancellation Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Cancellations made more than 30 days before the trek departure will receive a 90% refund. Cancellations between 15 and 30 days before departure will receive a 50% refund.'),
            const SizedBox(height: 16),
            const Text('No Refunds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('No refunds will be issued for cancellations made within 15 days of the trek departure date, or if a trekker fails to show up for the expedition.'),
            const SizedBox(height: 16),
            const Text('Force Majeure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('In case of cancellations by Trek India due to force majeure events (e.g., natural disasters, government restrictions), trekkers will receive a full refund or a credit towards a future trek.'),
            const SizedBox(height: 16),
            const Text('Refund Process', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Refunds will be processed within 7-10 business days after a valid cancellation request is received and approved.'),
          ],
        ),
      ),
    );
  }
}
