import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('PRIVACY POLICY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text('DATA PROTECTION PROTOCOLS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: const Text('Last revised: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 60, thickness: 1),
            
            _buildSection(context, 'I. INTRODUCTION', 'trekwithmussafirr ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share individual information when you use our mobile application.'),
            _buildSection(context, 'II. INFORMATION COLLECTION', 'We collect information you provide directly to us, such as when you create an account, book a trip, or contact support. This includes your name, email address, phone number, emergency contact details, and medical information necessary for your safety during trips.'),
            _buildSection(context, 'III. USAGE OF INFORMATION', 'We use your information to facilitate trip bookings, ensure your safety during expeditions, provide customer support, and improve our services. We may also use your contact information to send you updates and promotional materials related to trekwithmussafirr.'),
            _buildSection(context, 'IV. DATA SECURITY', 'We implement industry-standard security measures to protect your data from unauthorized access, alteration, or destruction. However, no method of transtrip over the internet or electronic storage is 100% secure.'),
            _buildSection(context, 'V. CONTACT trekwithmussafirr', 'If you have any questions about this Privacy Policy, please contact our details support team at support@tripindia.com.'),
            
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2))),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFD32F2F), size: 30),
                  SizedBox(width: 20),
                  Expanded(child: Text('YOUR DATA IS ENCRYPTED. We prioritize operational security and never share trip-critical personal data with unauthorized third parties.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD32F2F)))),
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
