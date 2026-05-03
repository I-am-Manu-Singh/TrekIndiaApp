import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactHikerScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const ContactHikerScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final profile = booking['profiles'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('STAFF RECORD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, profile),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _sectionTitle('OFFICIAL INFORMATION'),
                   const SizedBox(height: 16),
                   _infoTile(context, Icons.bloodtype, 'BLOOD GROUP', profile['blood_group'] ?? 'DATA RESTRICTED', Colors.redAccent),
                   _infoTile(context, Icons.emergency, 'EMERGENCY CONTACT', profile['emergency_contact'] ?? 'UNAVAILABLE', Colors.orangeAccent),
                   _infoTile(context, Icons.medical_services, 'MEDICAL DISCLOSURES', profile['medical_info'] ?? 'NO CLINICAL DATA', Colors.blueAccent),
                   
                   const SizedBox(height: 32),
                   _sectionTitle('TRIP ACTIONS'),
                   const SizedBox(height: 16),
                   _actionButton(context, Icons.phone, 'INITIATE VOICE COMMS', Colors.green, () {
                      if (profile['phone_number'] != null) launchUrl(Uri.parse('tel:${profile['phone_number']}'));
                   }),
                   const SizedBox(height: 12),
                   _actionButton(context, Icons.chat_bubble, 'ENCRYPTED DISPATCH', Colors.blue, () {
                      // Navigate to chat possibly
                   }),
                   const SizedBox(height: 12),
                   _actionButton(context, Icons.mail, 'OFFICIAL CORRESPONDENCE', Colors.grey, () {
                      // launch mail
                   }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Hero(
            tag: 'hiker_avatar_${profile['id']}',
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white10,
              backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
              child: profile['avatar_url'] == null ? const Icon(Icons.person, size: 40, color: Colors.white24) : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(profile['full_name']?.toUpperCase() ?? 'GUEST TRIPKER', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(profile['role'] ?? 'TRIP STAFF', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('BOOKING ID: ${booking['id'].toString().substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return FadeInLeft(
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.grey)),
    );
  }

  Widget _infoTile(BuildContext context, IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
    );
  }
}
