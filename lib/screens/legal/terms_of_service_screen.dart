import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TERMS OF SERVICE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text('TRIP ENGAGEMENT RULES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: const Text('Last revised: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 60, thickness: 1),
            
            _buildSection(context, 'I. ACCEPTANCE OF TERMS', 'By downloading, accessing, or using the Trip India mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.'),
            _buildSection(context, 'II. ELIGIBILITY', 'You must be at least 18 years old to use Trip India. Users under 18 must have the consent of a parent or legal guardian to participate in trips.'),
            _buildSection(context, 'III. USER ACCOUNTS', 'You are responsible for maintaining the confidentiality of your account information. You agree to notify us immediately of any unauthorized use of your account or any other breach of security.'),
            _buildSection(context, 'IV. TRIP PARTICIPATION', 'Trips are responsible for providing accurate health information and following all instructions from our guides to ensure their safety and the safety of others on the trip.'),
            _buildSection(context, 'V. LIMITATION OF LIABILITY', 'Trip India is not liable for any injuries, losses, or damages occurring during trips, except those resulting from our gross negligence or willful misconduct.'),
            
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2))),
              child: const Row(
                children: [
                  Icon(Icons.gavel_outlined, color: Color(0xFFD32F2F), size: 30),
                  SizedBox(width: 20),
                  Expanded(child: Text('TRIP COMPLIANCE REQUIRED. By engaging in a trip, you acknowledge the inherent risks of high-altitude trips and agree to our trip guidelines.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD32F2F)))),
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
