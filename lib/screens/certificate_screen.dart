import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class CertificateScreen extends StatelessWidget {
  final Map<String, dynamic> trekData;
  final String trekkerName;

  const CertificateScreen({
    super.key,
    required this.trekData,
    required this.trekkerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('TREK CERTIFICATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.amber.shade200, width: 10),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.terrain, color: Colors.blueGrey, size: 60),
                    const SizedBox(height: 12),
                    Text('TREK INDIA EXPEDITIONS', 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 14, letterSpacing: 3)),
                    const Text('OFFICE: MANALI, HP | +91 98765-43210', 
                      style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 48),
                    Text('CERTIFICATE OF ACHIEVEMENT', 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 24)),
                    const SizedBox(height: 12),
                    Text('ISSUED BY HQ COMMAND', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 48),
                    const Text('THIS IS TO CERTIFY THAT', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Text(trekkerName.toUpperCase(), 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 32, decoration: TextDecoration.underline)),
                    const SizedBox(height: 32),
                    const Text('HAS SUCCESSFULLY SURMOUNTED THE SUMMIT OF', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    Text(trekData['title']?.toString().toUpperCase() ?? 'THE PEAK', 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blueGrey)),
                    const SizedBox(height: 32),
                    _certStatsRow(),
                    const SizedBox(height: 60),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _signature('Trek Lead', 'Deepak Negi'),
                        const Icon(Icons.verified, color: Colors.amber, size: 40),
                        _signature('HQ Commander', 'Manpreet Singh'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('www.trekindiaexpeditions.com', style: TextStyle(fontSize: 8, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {}, 
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('SAVE IMAGE', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {}, 
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('DOWNLOAD PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Share your achievement with your squad!', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _certStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _certStat('ALTITUDE', trekData['max_altitude'] ?? '4,200m'),
        _certStat('DURATION', trekData['duration'] ?? '4 Days'),
        _certStat('DATE', trekData['completion_date'] ?? '20/03/2026'),
      ],
    );
  }

  Widget _certStat(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _signature(String role, String name) {
    return Column(
      children: [
         const Divider(color: Colors.black26),
         Text(name, style: GoogleFonts.nothingYouCouldDo(fontSize: 16)),
         Text(role.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
