import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  final String companyName = "Trek India Expeditions";
  final String phoneNumber = "+91 98765 43210";
  final String supportEmail = "support@trekindia.com";
  final String website = "https://trekindia.com";
  final String version = "1.0.0+1";

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('APP INFO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            FadeInDown(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                  ),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (c, e, s) => const Icon(Icons.terrain, size: 80, color: Colors.orangeAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              child: Column(
                children: [
                   Text(companyName.toUpperCase(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                   const SizedBox(height: 8),
                   Text('Build Version $version', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            _buildSectionTitle('OPERATIONAL CONTACTS'),
            const SizedBox(height: 16),
            _infoTile(Icons.phone_outlined, 'Tactical Support', phoneNumber, () => _launchUrl('tel:$phoneNumber'), isDark),
            _infoTile(Icons.email_outlined, 'Mission Control', supportEmail, () => _launchUrl('mailto:$supportEmail'), isDark),
            _infoTile(Icons.language_outlined, 'Digital Domain', website, () => _launchUrl(website), isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('FLANK ENGAGEMENT'),
            const SizedBox(height: 16),
            _infoTile(Icons.share_outlined, 'Share Frequency', 'Broadcast this app to your squad', () {
              Share.share('Join me on the most epic treks in India! Download Trek India Expeditions now: $website');
            }, isDark),
            _infoTile(Icons.star_outline, 'Rate Expedition', 'Quantify your mission experience', () {
              // Usually a store link or in_app_review. For now, a mock or website link.
              _launchUrl(website); 
            }, isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('SOCIAL FREQUENCIES'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialBtn(FontAwesomeIcons.instagram, () => _launchUrl('https://instagram.com'), isDark),
                _socialBtn(FontAwesomeIcons.facebook, () => _launchUrl('https://facebook.com'), isDark),
                _socialBtn(FontAwesomeIcons.twitter, () => _launchUrl('https://twitter.com'), isDark),
                _socialBtn(FontAwesomeIcons.youtube, () => _launchUrl('https://youtube.com'), isDark),
              ],
            ),
            const SizedBox(height: 30), // Reduced from 60
            Text('© 2026 Trek India Expeditions. All Rights Reserved.', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5), fontSize: 10)),
            const Text('E2E ENCRYPTED MISSION DATA', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeInLeft(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value, VoidCallback onTap, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 20),
          ),
          title: Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          subtitle: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.grey, size: 20),
        ),
      ),
    );
  }

  Widget _socialBtn(dynamic icon, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IconButton(
        icon: FaIcon(icon, color: isDark ? Colors.white54 : Colors.black54, size: 24),
        onPressed: onTap,
      ),
    );
  }
}
