
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/invoice_service.dart';

class DeclarationFormScreen extends StatefulWidget {
  final String tripTitle;
  const DeclarationFormScreen({super.key, required this.tripTitle});

  @override
  State<DeclarationFormScreen> createState() => _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends State<DeclarationFormScreen> {
  final List<Offset?> _points = [];
  bool _isAgreed = false;
  final TextEditingController _participantNameCtrl = TextEditingController();
  final TextEditingController _participantPhoneCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _medicalCtrl = TextEditingController();
  final TextEditingController _emergencyNameCtrl = TextEditingController();
  final TextEditingController _emergencyPhoneCtrl = TextEditingController();

  // GlobalKey to correctly resolve touch coordinates relative to the signature pad
  final GlobalKey _signatureKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isSaving = false;
  String? _declarationUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final p = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (p != null && mounted) {
        setState(() {
          _participantNameCtrl.text = p['full_name'] ?? '';
          _participantPhoneCtrl.text = p['phone_number'] ?? '';
          _medicalCtrl.text = p['medical_info'] ?? '';
          if (p['emergency_contact'] != null) {
            final ec = p['emergency_contact'].toString();
            if (ec.contains('(') && ec.contains(')')) {
              _emergencyNameCtrl.text = ec.split('(').first.trim();
              _emergencyPhoneCtrl.text = ec.split('(').last.replaceAll(')', '').trim();
            } else {
              _emergencyNameCtrl.text = ec;
            }
          }
        });
      }
    }
  }

  Future<Uint8List?> _captureSignatureBytes() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDeclaration({bool shareToWhatsapp = false}) async {
    if (!_isAgreed || _points.where((p) => p != null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign and agree to the risk declaration.')));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      final String hikerName = _participantNameCtrl.text.trim().isNotEmpty
          ? _participantNameCtrl.text.trim()
          : (user.userMetadata?['full_name'] ?? 'Adventurer');

      // 0. Capture user's exact hand-drawn touchscreen signature
      final signatureBytes = await _captureSignatureBytes();

      // 1. Generate Certified Declaration PDF bytes with embedded drawn signature
      final pdfBytes = await InvoiceService.generateDeclarationPdfBytes(
        hikerName: hikerName,
        tripTitle: widget.tripTitle,
        emergencyContact: '${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})',
        medicalInfo: _medicalCtrl.text,
        date: DateTime.now(),
        signatureImageBytes: signatureBytes,
      );

      // 2. Upload to Supabase Storage 'payment_proofs' or 'avatars' / public storage
      String? publicUrl;
      try {
        final fileName = 'declaration_${user.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await Supabase.instance.client.storage.from('payment_proofs').uploadBinary(
          fileName,
          pdfBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
        publicUrl = Supabase.instance.client.storage.from('payment_proofs').getPublicUrl(fileName);
      } catch (_) {}

      // 3. Update profiles table with declaration details & declaration_url
      await Supabase.instance.client.from('profiles').update({
        'emergency_contact': '${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})',
        'medical_info': _medicalCtrl.text,
        'declaration_signed': true,
        'declaration_url': publicUrl ?? _declarationUrl,
        'last_declaration_date': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _declarationUrl = publicUrl;
        });

        if (shareToWhatsapp) {
          final msg = "Hello trekwithmussafirr Team,\n\nI have digitally signed my Risk Declaration & Medical Consent form for ${widget.tripTitle}.\nParticipant: $hikerName\nEmergency Contact: ${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})${publicUrl != null ? '\n\nDocument: $publicUrl' : ''}";
          final waUrl = "https://wa.me/919756399115?text=${Uri.encodeComponent(msg)}";
          launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
        }

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Risk Declaration verified & registered!'), backgroundColor: Colors.green),
        );
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
                  const Text('Please review the terms, provide medical & emergency details, and sign below.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('PARTICIPANT INFORMATION'),
            const SizedBox(height: 12),
            TextField(
              controller: _participantNameCtrl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Legal Name *',
                hintText: 'As per Aadhar / Govt ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _participantPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: '+91 ...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      hintText: 'e.g. 24',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'City & State',
                hintText: 'e.g. Dehradun, Uttarakhand',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('MEDICAL HISTORY & ALLERGIES'),
            const SizedBox(height: 12),
            TextField(
              controller: _medicalCtrl,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Any asthma, allergies, past surgeries, or medical conditions (Write "None" if fit)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('EMERGENCY CONTACT PERSON'),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyNameCtrl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Contact Person Name *',
                hintText: 'Parent / Spouse / Relative',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Emergency Contact Phone Number *',
                hintText: '+91 9756399115',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('MEDICAL & HIGH ALTITUDE DECLARATION'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.04),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.withOpacity(0.15)),
              ),
              child: const Text(
                'Trek With Mussafirr treks take place in some remote and less-developed regions, without means of rapid evacuation, or medical supplies and facilities. In the event of an accident, illness, or other hazardous terrain, common and uncommon signs and symptoms of altitude sickness should be expected. These include, but are not limited to: sleeplessness, coughing, loss of appetite, nausea, vomiting, and muscle cramps. Severe cases of altitude sickness can include pulmonary and/or cerebral oedema. In addition, exposure to microorganisms unknown to our digestive system may cause symptoms from a wide array of gastrointestinal disorders despite the best efforts to treat drinking water and prepare food properly. A poor state of health can greatly increase the dangers and risks that can be incurred on these trips. Therefore, Trek With Mussafirr requires that all climbers and/or trekkers are examined by a physician, are properly immunized for the destination(s), and provide information.',
                style: TextStyle(fontSize: 10.5, color: Colors.black87, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('TERMS & CONDITIONS OF SERVICE & TRIP PARTICIPATION AGREEMENT'),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                collapsedBackgroundColor: Colors.grey.withOpacity(0.05),
                backgroundColor: Colors.grey.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                leading: const Icon(Icons.gavel_outlined, color: Color(0xFFD32F2F), size: 20),
                title: const Text('Read Complete 23 Legal Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: const Text('Tap to expand full verbatim contract from official document', style: TextStyle(fontSize: 10, color: Colors.grey)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'This Agreement ("Agreement") is entered into by and between Trek With Mussafirr ("TWM"), having its registered office at 383 street no. 11 Rajendra Nagar, Shiv Complex cabin no. 4, 2nd floor, Dehradun-248001, Uttarakhand (hereinafter referred to as "TWM"), and the Client (hereinafter referred to as the "Participant"). The booking of any trekking, mountaineering, adventure activity ("Trip") or any trip with TWM, constitutes acceptance of the terms and conditions set forth herein and forms a legally binding contract between TWM and the Participant.\n',
                          style: TextStyle(fontSize: 10, color: Colors.black87, height: 1.3),
                        ),
                        _TermClause(number: '1', title: 'Acceptance of Risk and Participant Responsibility', body: 'The Participant acknowledges that participation in any Trip involves inherent risks, including but not limited to injury, illness, loss, or death, due to unpredictable weather, terrain, or other environmental and non-environmental conditions.\nThe Participant voluntarily assumes all such risks and agrees to be solely responsible for their personal safety, fitness, and decision to participate.\nThe Participant agrees to disclose any relevant medical, psychological, or physical conditions prior to booking and undertakes that they are fit and well-prepared for the selected Trip.\nTWM undertakes reasonable measures to minimize risks but cannot guarantee a risk-free experience.'),
                        _TermClause(number: '2', title: 'Booking and Payments', body: 'Booking of a Trip constitutes unconditional acceptance of this Agreement by the Participant and all persons represented by the Participant.\nThe Participant is responsible for verifying the accuracy of all details, including Trip dates and personal documentation, at the time of booking.\nPayments must be made in accordance with the timelines and instructions provided by TWM. Late payments may result in cancellation of booking without refund.\nIn the event of a cash refund, only the portion of the payment made in cash shall be eligible for refund in cash. Any booking made using voucher, discounts, promotional codes, or through any non-cash mode of payment shall not be eligible for a cash refund under any circumstances.\nRefunds, if applicable, shall be processed within 15-30 working days of confirmation.\nVoucher Terms: Non-transferable; cannot be merged with other offers; valid for 1 year for trips booked directly in India using registered email/phone.'),
                        _TermClause(number: '3', title: 'Minor Participation Policy', body: 'Participants under 15 years of age must be accompanied by a parent or legal guardian and must submit a signed consent form. Participants between 15 to 18 years can come solo with the disclaimer form signed by parent/guardian.'),
                        _TermClause(number: '4', title: 'Promotional Material', body: 'Photographs and videos used on TWM\'s website, social media, or promotional content are illustrative and do not form part of the Trip package or service guarantee.'),
                        _TermClause(number: '5', title: 'Documentation and Permits', body: 'All required documentation must be submitted by the Participant prior to the Trip. TWM is not liable for failure to provide services due to incomplete, incorrect, or missing documentation.'),
                        _TermClause(number: '6', title: 'Communication', body: 'All official communication shall be made via the email ID submitted during registration. Participants must notify TWM at mussafirr1@gmail.com of any changes. You consent to receive communications via email, phone calls, and SMS.'),
                        _TermClause(number: '7', title: 'Insurance Advisory', body: 'TWM strongly encourages all Participants to obtain comprehensive travel insurance covering high-altitude trekking, illness, hospitalisation, evacuation, and trip cancellations. If not obtained, one is provided by default for Indian citizens as third-party insurance with zero liability on TWM.'),
                        _TermClause(number: '8', title: 'Amenities and Conditions', body: 'Participants acknowledge that these regions offer limited amenities. Environmental and logistical constraints may affect comfort. TWM is not liable for discomfort arising therefrom.'),
                        _TermClause(number: '9', title: 'Expenses, Rental Equipments and Exclusions', body: 'Excluded from Trip cost: Insurance, airfares, visa costs, evacuation expenses, personal expenses, gear rentals, and porter/mule fees. Shoes, poles, headlights, jackets, microspikes, gaiters, etc. are not included in packages. Any damage or loss to rented equipment must be fully paid and reimbursed by the Participant.'),
                        _TermClause(number: '10', title: 'Luggage and Personal Belongings', body: 'All baggage and personal belongings are the sole responsibility of the Participant. TWM shall not be liable for loss, damage, or theft.'),
                        _TermClause(number: '11', title: 'Optional Activities', body: 'Optional activities not included in the Trip package are undertaken at the Participant\'s own risk. TWM shall not be held liable for resulting loss, injury, or damage.'),
                        _TermClause(number: '12', title: 'Force Majeure', body: 'TWM shall not be held liable for cancellation, delay, or service modification caused by events beyond its control including earthquakes, landslides, strikes, curfews, war, pandemic, government restrictions, heavy rainfall or snowfall, windstorms, road blockages, trail disruption, or permit withdrawals. No refunds, liability, or compensation arise from Force Majeure.'),
                        _TermClause(number: '13', title: 'Itinerary and Modifications', body: 'TWM reserves the right to modify, shorten, or cancel any part of the Trip due to transport delays, weather, health emergencies, or Force Majeure. Additional expenses are borne by the Participant.'),
                        _TermClause(number: '14', title: 'Cancellations and Refunds', body: 'No refunds or vouchers provided for voluntary withdrawal or removal. If TWM cancels before pick-up point arrival due to Force Majeure: alternate date, 1-year credit voucher, or trip transfer. Discontinuation due to health, AMS, or weather is strictly 100% non-refundable. En-route exits between Point A to Point B require participant to bear all transport, accommodation, meals, porter, and evacuation expenses entirely.'),
                        _TermClause(number: '15', title: 'Conditions to Discontinue a Trip for a Participant', body: 'Condition 1: AMS Unconscious / Conscious / Ill critical / Injured.\nCondition 2: High Blood pressure, SpO2 below 80%, irregular heart rate.\nCondition 3: Symptoms like headache, nausea, dizziness, fatigue, confusion.\nCondition 4: Unable to meet group average speed.\nCondition 5: Use of alcohol, drugs, smoking on trails/camps, offensive language or disturbance.'),
                        _TermClause(number: '16', title: 'Medical Emergencies and Evacuation', body: 'All hospitalisation, doctor fees, evacuation, or repatriation expenses are borne solely by the Participant.'),
                        _TermClause(number: '17', title: 'Third Party Services and Manpower', body: 'Porters, guides, and mule operators are third-party vendor contractors. TWM is not liable for non-performance, illness, or departure of support staff.'),
                        _TermClause(number: '18', title: 'Photography, Media, Data Privacy & Usage', body: 'Participant grants TWM a royalty-free license to use trip media for promotional purposes unless opted out in writing. Data is stored for operational and legal purposes only.'),
                        _TermClause(number: '19', title: 'Blacklist Policy', body: 'TWM reserves the right to permanently blacklist any individual for misconduct, safety violations, defamation, or harassment without refund.'),
                        _TermClause(number: '20', title: 'Implied Acceptance and Waiver of Objection', body: 'Concerns must be communicated immediately to trip leader. Continued utilization of services constitutes implied acceptance, waiving retrospective claims.'),
                        _TermClause(number: '21', title: 'Complaints & Dispute Resolution', body: 'Complaints must be submitted via email within 7 days. Arbitration conducted in Dehradun under Indian law.'),
                        _TermClause(number: '22', title: 'Governing Law & Jurisdiction', body: 'Governed by Indian law. All legal disputes fall under the exclusive jurisdiction of courts in Dehradun, Uttarakhand.'),
                        _TermClause(number: '23', title: 'Miscellaneous', body: 'Trek With Mussafirr holds rights to add/remove any Terms without prior notice.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('DISCLAIMER AND DECLARATION'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
              child: const Text(
                'The Trek/Expedition route in The Himalayas has its share of risks and dangers, especially in respect to the terrain, weather, high altitude, and desolate nature. Accidents on this trek can cause one to get injured, fall ill, and death too cannot be ruled out.\n\nI hereby declare that my participation in this trek is completely voluntary, and I am fully aware of the risks involved. I will not hold Trekwithmussafirr wholly or partly responsible in case of any accident, illness, injury, or death on the trek.',
                style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _isAgreed,
              onChanged: (v) => setState(() => _isAgreed = v!),
              title: const Text('I have read and unconditionally agree to all 23 Terms & Conditions and the Risk Disclaimer.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: Container(
                    color: Colors.white,
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
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSaving ? null : () => _saveDeclaration(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SUBMIT & REGISTER DECLARATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _saveDeclaration(shareToWhatsapp: true),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Color(0xFF25D366)),
                    label: const Text('SUBMIT & SHARE (WHATSAPP)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final user = Supabase.instance.client.auth.currentUser;
                      final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', user?.id ?? '').maybeSingle();
                      final sigBytes = await _captureSignatureBytes();
                      InvoiceService.downloadDeclarationPdf(
                        hikerName: profile?['full_name'] ?? 'Adventurer',
                        tripTitle: widget.tripTitle,
                        emergencyContact: '${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})',
                        medicalInfo: _medicalCtrl.text,
                        date: DateTime.now(),
                        signatureImageBytes: sigBytes,
                      );
                    },
                    icon: const Icon(Icons.download, size: 16, color: Colors.blueAccent),
                    label: const Text('DOWNLOAD PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueAccent),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
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

class _TermClause extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _TermClause({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(body, style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.3)),
        ],
      ),
    );
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
