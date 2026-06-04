import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'legal/refund_policy_screen.dart';
import 'legal/safety_protocols_screen.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  final String companyName = "TREK WITH MUSSAFIRR";
  final String phoneNumber = "+91 98765 43210";
  final String supportEmail = "trekwithmussafirr@gmail.com";
  final String website = "https://trekwithmussafirr.com";
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
        title: const Text('APP INFO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
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
                    border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2)),
                  ),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (c, e, s) => const Icon(Icons.terrain, size: 80, color: Color(0xFFD32F2F)),
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

          const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _smallActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {
                      Share.share(
                        'Join me on the most epic trips in India! Download trekwithmussafirr Expeditions now: $website',
                      );
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _smallActionBtn(
                    icon: Icons.star_outline,
                    label: 'Rate',
                    onTap: () {
                      _launchUrl(website);
                    },
                    isDark: isDark,
                  ),
                ],
              ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialBtn(FontAwesomeIcons.instagram, () => _launchUrl('https://instagram.com'), isDark),
                _socialBtn(FontAwesomeIcons.facebook, () => _launchUrl('https://facebook.com'), isDark),
                _socialBtn(FontAwesomeIcons.twitter, () => _launchUrl('https://twitter.com'), isDark),
                _socialBtn(FontAwesomeIcons.youtube, () => _launchUrl('https://youtube.com'), isDark),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionTitle('CUSTOMER SUPPORT'),
            const SizedBox(height: 12),
            _infoTile(Icons.phone_outlined, 'Customer Support Number', phoneNumber, () => _launchUrl('tel:$phoneNumber'), isDark),
            _infoTile(Icons.email_outlined, 'Customer Support Email', supportEmail, () => _launchUrl('mailto:$supportEmail'), isDark),
            _infoTile(Icons.language_outlined, 'Official Website', website, () => _launchUrl(website), isDark),
            const SizedBox(height: 12),
            _buildSectionTitle('IMPORTANT DOCUMENTS'),
        const SizedBox(height: 12),
        _infoTile(Icons.privacy_tip_outlined, 'Privacy Policy', 'Data protection protocols', 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PrivacyPolicyScreen())), isDark),
        _infoTile(Icons.gavel_outlined, 'Terms of Service', 'Trip engagement rules', 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TermsOfServiceScreen())), isDark),
        _infoTile(Icons.monetization_on_outlined, 'Refund Policy', 'Fiscal cancellation info', 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RefundPolicyScreen())), isDark),
        _infoTile(Icons.health_and_safety_outlined, 'Safety Protocols', 'Trip survival rules', 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SafetyProtocolsScreen())), isDark),
        const SizedBox(height: 30), // Reduced from 60
            Text('© 2026 trekwithmussafirr Expeditions. All Rights Reserved.', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5), fontSize: 10)),
            const Text('E2E ENCRYPTED TRIP DATA', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeInLeft(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value, VoidCallback onTap, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
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
Widget _smallActionBtn({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
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
