import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('REFUND POLICY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text('FISCAL CANCELLATION INFO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: const Text('Last revised: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 60, thickness: 1),
            
            _buildSection(context, 'I. CANCELLATION FEES', 'Cancellations made more than 30 days before the trip departure will receive a 90% refund. Cancellations between 15 and 30 days before departure will receive a 50% refund.'),
            _buildSection(context, 'II. NO REFUNDS', 'No refunds will be issued for cancellations made within 15 days of the trip departure date, or if a trip fails to show up for the expedition.'),
            _buildSection(context, 'III. FORCE MAJEURE', 'In case of cancellations by Trip India due to force majeure events (e.g., natural disasters, government restrictions), trips will receive a full refund or a credit towards a future trip.'),
            _buildSection(context, 'IV. REFUND PROCESS', 'Refunds will be processed within 7-10 business days after a valid cancellation request is received and approved.'),
            
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2))),
              child: const Row(
                children: [
                  Icon(Icons.monetization_on_outlined, color: Color(0xFFD32F2F), size: 30),
                  SizedBox(width: 20),
                  Expanded(child: Text('FISCAL STABILITY SECURED. Our refund protocols ensure trip viability while providing fair compensation for operational adjustments.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD32F2F)))),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFD32F2F), letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(content, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }
}
