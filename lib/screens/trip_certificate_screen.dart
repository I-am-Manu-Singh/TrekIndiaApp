import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class TripCertificateScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const TripCertificateScreen({super.key, required this.booking});

  @override
  State<TripCertificateScreen> createState() => _TripCertificateScreenState();
}

class _TripCertificateScreenState extends State<TripCertificateScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareCertificate() async {
    final image = await _screenshotController.capture();
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/certificate.png').create();
      await imagePath.writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath.path)], text: 'Achievement Unlocked: Finished ${widget.booking['trips']['title']} with trekwithmussafirr!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.booking['trip'] ?? {};
    final user = widget.booking['profiles'] ?? {};
    final tripName = trip['title'] ?? 'Himalayan Expedition';
    final userName = user['full_name'] ?? 'Adventurer';
    final height = (trip['peak_elevation'] ?? trip['altitude'] ?? '4,500m').toString();
    final duration = (trip['duration'] ?? '5 Days').toString();
    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.parse(widget.booking['trip_date']));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CONTROL ACHIEVEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.blueAccent), onPressed: _shareCertificate),
        ],
      ),
      body: Stack(
        children: [
          // Background Cinematic Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&q=80&w=2070',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent, Colors.black.withOpacity(0.9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                        child: FadeInUp(
                          child: Screenshot(
                            controller: _screenshotController,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                width: 450,
                                height: 700,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 50)],
                                  border: Border.all(color: Colors.amber.shade700, width: 12),
                                  image: const DecorationImage(
                                    image: NetworkImage('https://www.transparenttextures.com/patterns/natural-paper.png'),
                                    repeat: ImageRepeat.repeat,
                                    opacity: 0.1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -40, top: -40,
                                      child: Opacity(
                                        opacity: 0.05,
                                        child: Icon(Icons.terrain, size: 280, color: Colors.amber.shade900),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Text('TREKWITHMUSSAFIRR EXPEDITIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 6, color: Colors.black)),
                                        const SizedBox(height: 8),
                                        Divider(color: Colors.amber.shade800, thickness: 1.5, indent: 110, endIndent: 110),
                                        const Spacer(flex: 2),
                                        Text('CERTIFICATE', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 38, color: Colors.black87, letterSpacing: 8)),
                                        Text('OF COMPLETION', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade800, letterSpacing: 3)),
                                        const Spacer(flex: 2),
                                        Text('THIS IS TO CERTIFY THAT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 4)),
                                        const SizedBox(height: 32),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Container(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: Colors.black12, width: 2)),
                                              ),
                                              child: Text(
                                                userName.toUpperCase(),
                                                style: GoogleFonts.bodoniModa(
                                                  fontSize: 42,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 2,
                                                  color: const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 48),
                                        Text('HAS SUCCESSFULLY CONQUERED THE SUMMIT OF', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
                                        const SizedBox(height: 12),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 24),
                                            child: Text(
                                              tripName.toUpperCase(),
                                              style: GoogleFonts.cinzel(
                                                color: const Color(0xFF4A6572),
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 48),
                                        
                                        // Trip Telemetry (Metadata)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 16,
                                            runSpacing: 16,
                                            children: [
                                              _premiumDetail('ALTITUDE', height, Icons.filter_hdr),
                                              _premiumDetail('DURATION', duration, Icons.timer),
                                              _premiumDetail('DATE', dateStr.split(' ')[0], Icons.calendar_today),
                                            ],
                                          ),
                                        ),
                                        const Spacer(flex: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              _footerSign('DATE', DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.booking['trip_date']))),
                                              const SizedBox(width: 20),
                                              _leaderSign('TRIP LEADER', 'S. SHARMA'),
                                              const SizedBox(width: 20),
                                              _seal(),
                                              const SizedBox(width: 20),
                                              _leaderSign('CMD. OFFICER', 'M. SINGH'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _shareCertificate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 10,
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('SHARE ACHIEVEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumDetail(String label, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.amber.shade800),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(val, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
      ],
    );
  }

  Widget _leaderSign(String label, String name) {
    return Column(
      children: [
        Text(name, style: GoogleFonts.dancingScript(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        Container(width: 80, height: 1, color: Colors.black26),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _seal() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber.shade800, width: 2)),
      child: Icon(Icons.verified, size: 40, color: Colors.amber.shade800),
    );
  }

  Widget _footerSign(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        Container(width: 80, height: 1, color: Colors.black26),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }
}
