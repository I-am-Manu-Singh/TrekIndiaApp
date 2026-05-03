
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class DeclarationFormScreen extends StatefulWidget {
  final String tripTitle;
  const DeclarationFormScreen({super.key, required this.tripTitle});

  @override
  State<DeclarationFormScreen> createState() => _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends State<DeclarationFormScreen> {
  final List<Offset?> _points = [];
  bool _isAgreed = false;
  final TextEditingController _medicalCtrl = TextEditingController();
  final TextEditingController _emergencyNameCtrl = TextEditingController();
  final TextEditingController _emergencyPhoneCtrl = TextEditingController();

  // GlobalKey to correctly resolve touch coordinates relative to the signature pad
  final GlobalKey _signatureKey = GlobalKey();
  bool _isSaving = false;

  void _saveDeclaration() async {
    if (!_isAgreed || _points.where((p) => p != null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign and agree to the terms.')));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      // In a real app, we would convert _points to an image and upload to storage.
      // For now, we'll store the medical info and a flag in profiles/bookings.
      await Supabase.instance.client.from('profiles').update({
        'emergency_contact': '${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})',
        'medical_info': _medicalCtrl.text,
        'declaration_signed': true,
        'last_declaration_date': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // Verify
      final verify = await Supabase.instance.client.from('profiles').select('declaration_signed').eq('id', user.id).single();

      if (mounted) {
        if (verify['declaration_signed'] == true) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declaration registered successfully!'), backgroundColor: Colors.green));
        } else {
          throw Exception('Failed to register. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RISK DECLARATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRIP: ${widget.tripTitle.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFD32F2F))),
                  const SizedBox(height: 8),
                  const Text('Please provide accurate medical information and sign the risk acknowledgement below.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('MEDICAL HISTORY'),
            const SizedBox(height: 12),
            TextField(
              controller: _medicalCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any allergies, past surgeries, or medical conditions...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('EMERGENCY CONTACT'),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyNameCtrl,
              decoration: InputDecoration(
                labelText: 'Contact Person Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Phone Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('RISK ACKNOWLEDGEMENT'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
              child: const Text(
                'I hereby declare that I am physically fit to participate in this trip. I understand the risks involved in high-altitude tripking and outdoor activities. I will not hold Trip India or its staff responsible for any accidents or health issues occurring during the trip.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _isAgreed,
              onChanged: (v) => setState(() => _isAgreed = v!),
              title: const Text('I agree to the terms and conditions mentioned above.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('DIGITAL SIGNATURE'),
            const SizedBox(height: 4),
            const Text('Draw your signature in the box below', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 12),
            Container(
              key: _signatureKey,
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _points.where((p) => p != null).isNotEmpty ? const Color(0xFFD32F2F) : Colors.grey.shade300, width: _points.where((p) => p != null).isNotEmpty ? 2 : 1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      final RenderBox? renderBox = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        _points.add(renderBox.globalToLocal(details.globalPosition));
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final RenderBox? renderBox = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        _points.add(renderBox.globalToLocal(details.globalPosition));
                      }
                    });
                  },
                  onPanEnd: (details) => _points.add(null),
                  child: CustomPaint(
                    painter: SignaturePainter(List.from(_points)),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _points.clear()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('CLEAR SIGNATURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (_points.where((p) => p != null).isNotEmpty)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text('SIGNED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveDeclaration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SUBMIT DECLARATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey));
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
