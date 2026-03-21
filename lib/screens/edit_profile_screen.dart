import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) setState(() { _userData = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionAlert(isDark),
            const SizedBox(height: 12),
            const Text('  CORE IDENTITY TELEMETRY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            _buildProfileFields(),
            const SizedBox(height: 12),
            const Text('  TREK DOCUMENTATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            _dossierCard(Icons.badge_outlined, 'PASSPORT / ID PROOF', _userData?['passport_url'] ?? 'No document uploaded', 'passport_url'),
            const SizedBox(height: 6),
            _dossierCard(Icons.fingerprint_outlined, 'AADHAR CARD', _userData?['aadhar_url'] ?? 'No document uploaded', 'aadhar_url'),
            const SizedBox(height: 6),
            _dossierCard(Icons.medical_services_outlined, 'MEDICAL CERTIFICATE', _userData?['medical_certificate_url'] ?? 'No document uploaded', 'medical_certificate_url'),
            const SizedBox(height: 12),
            const Text('  SECURITY TELEMETRY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            _buildSecuritySection(),
            const SizedBox(height: 12),
            const Center(child: Text('All data is encrypted and visible only to HQ Commanders.', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileFields() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: _userData?['full_name']);
    final phoneCtrl = TextEditingController(text: _userData?['phone_number']);
    final emergencyCtrl = TextEditingController(text: _userData?['emergency_contact']);
    final bloodCtrl = TextEditingController(text: _userData?['blood_group']);
    final medicalCtrl = TextEditingController(text: _userData?['medical_info']);

    return Container(
     padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(25),
  border: Border.all(
    color: isDark ? Colors.white10 : const Color(0xFFE8F5E9),
  ),
),
child: Column(
  children: [
    _field(nameCtrl, 'FULL NAME', Icons.person_outline, isDark),
    const SizedBox(height: 6),
    _field(phoneCtrl, 'PHONE NUMBER', Icons.phone_android, isDark),
    const SizedBox(height: 6),
    _field(emergencyCtrl, 'EMERGENCY CONTACT', Icons.emergency_outlined, isDark),
    const SizedBox(height: 6),
    _field(bloodCtrl, 'BLOOD GROUP', Icons.opacity, isDark),
    const SizedBox(height: 6),
    _field(medicalCtrl, 'MEDICAL INFO(any allergies/disease)', Icons.health_and_safety_outlined, isDark),
    const SizedBox(height: 6),
    SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () async {
          try {
            await _client.from('profiles').update({
              'full_name': nameCtrl.text,
              'phone_number': phoneCtrl.text,
              'emergency_contact': emergencyCtrl.text,
              'blood_group': bloodCtrl.text,
              'medical_info': medicalCtrl.text,
            }).eq('id', _client.auth.currentUser!.id);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SQUAD TELEMETRY UPDATED.'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('UPDATE FAILED: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7B32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          'SAVE IDENTITY CHANGES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  ],
),
);
}

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool isDark) {
    return TextField(
      controller: ctrl,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF2E7B32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE8F5E9))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE8F5E9))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildActionAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withOpacity(0.05) : const Color(0xFFE3F2FD), 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade100)
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF42A5F5), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14)),
          const SizedBox(width: 16),
          Expanded(child: Text('Trek clearance requires verified documentation. HQ will audit these files before trek departure.', style: TextStyle(color: isDark ? Colors.blue.shade200 : const Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold, height: 1.4))),
        ],
      ),
    );
  }
Widget _dossierCard(IconData icon, String title, String url, String field) {
  bool hasFile = url.startsWith('http');
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white10 : const Color(0xFFE8F5E9),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF2E7B32)),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            // 🔴 Status icon
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasFile
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
              ),
              child: Icon(
                hasFile ? Icons.check : Icons.close,
                size: 14,
                color: hasFile ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 📦 URL + ✏️ inside same boundary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),

              GestureDetector(
                onTap: () => _replaceDoc(field, title),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF2E7B32),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  void _replaceDoc(String field, String title) async {
    final TextEditingController _controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('UPDATE $title'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Enter Document URL (G-Drive / Cloud)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(c, _controller.text), child: const Text('UPDATE')),
        ],
      )
    );

    if (url != null && url.isNotEmpty) {
      try {
        await _client.from('profiles').update({field: url}).eq('id', _client.auth.currentUser!.id);
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document updated for HQ review.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Widget _buildSecuritySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(25), 
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8F5E9))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Establish a permanent tactical password for direct terminal login. Highly recommended for users currently using satellite OAuth (Google).', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'NEW TREK PASSWORD',
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.pinkAccent),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'CONFIRM TREK PASSWORD',
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              prefixIcon: const Icon(Icons.security, size: 18, color: Colors.pinkAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _updateTrekPassword,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('AUTHORIZE SECURITY KEY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTrekPassword() async {
    if (_passwordController.text.isEmpty || _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match or are empty.')));
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.')));
      return;
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: _passwordController.text.trim()));
      _passwordController.clear();
      _confirmPasswordController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TREK PASSWORD ESTABLISHED.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PROVISIONING FAILED: $e'), backgroundColor: Colors.red));
    }
  }
}
