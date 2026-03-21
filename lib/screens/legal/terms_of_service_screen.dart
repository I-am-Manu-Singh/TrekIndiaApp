import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms of Service for Trek India', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last updated: March 20, 2026', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text('Acceptance of Terms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('By downloading, accessing, or using the Trek India mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.'),
            const SizedBox(height: 16),
            const Text('Eligibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You must be at least 18 years old to use Trek India. Users under 18 must have the consent of a parent or legal guardian to participate in treks.'),
            const SizedBox(height: 16),
            const Text('User Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You are responsible for maintaining the confidentiality of your account information. You agree to notify us immediately of any unauthorized use of your account or any other breach of security.'),
            const SizedBox(height: 16),
            const Text('Trek Participation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Trekkers are responsible for providing accurate health information and following all instructions from our guides to ensure their safety and the safety of others on the trek.'),
            const SizedBox(height: 16),
            const Text('Limitation of Liability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Trek India is not liable for any injuries, losses, or damages occurring during treks, except those resulting from our gross negligence or willful misconduct.'),
          ],
        ),
      ),
    );
  }
}
