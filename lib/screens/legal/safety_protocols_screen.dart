import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class SafetyProtocolsScreen extends StatelessWidget {
  const SafetyProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('SAFETY PROTOCOLS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text('TRIP SAFETY STANDARDS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: const Text('Last revised: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 60, thickness: 1),
            
            _buildSection(context, 'I. PRE-TRIP BRIEFING', 'All trips must undergo a mandatory details briefing before departure. This covers route terrain, weather expectations, and communications protocols.'),
            _buildSection(context, 'II. MEDICAL CLEARANCE', 'Participants must present valid medical certification. Our team reserves the right to deny participation if physical fitness requirements are not met.'),
            _buildSection(context, 'III. FIELD GEAR STANDARDS', 'Only certified gear (either personal or issued by our trekwithmussafirr) is permitted. Our guides perform a multi-point equipment check before trip.'),
            _buildSection(context, 'IV. EMERGENCY EVACUATION', 'In case of severe altitude sickness (AMS) or injury, a satellite-linked evacuation protocol is triggered. Extraction costs are covered by the specific trip insurance.'),
            _buildSection(context, 'V. WILDLIFE ENCOUNTERS', 'Strict non-interference protocols are in effect. Trips must follow guide instructions during any interaction with local fauna.'),
            
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.2))),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                  SizedBox(width: 20),
                  Expanded(child: Text('SAFETY IS NON-NEGOTIABLE. Violating guide instructions results in immediate trip termination without refund.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent))),
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
