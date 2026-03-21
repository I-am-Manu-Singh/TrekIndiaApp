import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy Policy for Trek India', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last updated: March 20, 2026', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text('Introduction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Trek India ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share individual information when you use our mobile application.'),
            const SizedBox(height: 16),
            const Text('Information Collection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('We collect information you provide directly to us, such as when you create an account, book a trek, or contact support. This includes your name, email address, phone number, emergency contact details, and medical information necessary for your safety during treks.'),
            const SizedBox(height: 16),
            const Text('Usage of Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('We use your information to facilitate trek bookings, ensure your safety during expeditions, provide customer support, and improve our services. We may also use your contact information to send you updates and promotional materials related to Trek India.'),
            const SizedBox(height: 16),
            const Text('Data Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('We implement industry-standard security measures to protect your data from unauthorized access, alteration, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.'),
            const SizedBox(height: 16),
            const Text('Contact Us', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('If you have any questions about this Privacy Policy, please contact us at support@trekindia.com.'),
          ],
        ),
      ),
    );
  }
}
