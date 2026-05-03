import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();
  
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
      if (mounted && res != null) {
        String? name = res['full_name'];
        if (name == null || name.trim().isEmpty || name == 'Explorer') {
          name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
          if (name == null || name.trim().isEmpty) {
            name = user.email?.split('@')[0] ?? 'Explorer';
            _client.from('profiles').update({'full_name': name}).eq('id', user.id).then((_) {});
          }
        }
        setState(() {
          _userData = res;
          _nameCtrl.text = name ?? '';
          _phoneCtrl.text = res['phone_number'] ?? '';
          _emergencyCtrl.text = res['emergency_contact'] ?? '';
          _bloodCtrl.text = res['blood_group'] ?? '';
          _medicalCtrl.text = res['medical_info'] ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark, primaryColor),
                const SizedBox(height: 40),
                
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('PERSONAL INFORMATION'),
                      const SizedBox(height: 12),
                      _buildInfoCard(isDark, primaryColor),
                    ],
                  ),
                ),
                
                const SizedBox(height: 22),
                
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('TRIP DOCUMENTATION'),
                      const SizedBox(height: 12),
                      _buildDocumentsSection(isDark),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('SECURITY & ACCESS'),
                      const SizedBox(height: 12),
                      _buildSecurityCard(isDark),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                Center(
                  child: Opacity(
                    opacity: 0.5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'DATA ENCRYPTED & AUDITED BY TRIP INDIA HQ',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader(bool isDark, Color primaryColor) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withOpacity(0.3), width: 3),
            ),
            child: UserAvatar(
              imageUrl: _userData?['avatar_url'],
              name: _userData?['full_name'],
              width: 100,
              height: 100,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          GestureDetector(
            onTap: () => _replaceDoc('avatar_url', 'PROFILE PICTURE'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF0F172A) : Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          _modernField(_nameCtrl, 'FULL NAME', Icons.person_outline, isDark),
          const SizedBox(height: 16),
          _modernField(_phoneCtrl, 'PHONE NUMBER', Icons.phone_android_outlined, isDark),
          const SizedBox(height: 16),
          _modernField(_emergencyCtrl, 'EMERGENCY CONTACT', Icons.contact_emergency_outlined, isDark),
          const SizedBox(height: 16),
          _modernField(_bloodCtrl, 'BLOOD GROUP', Icons.bloodtype_outlined, isDark),
          const SizedBox(height: 16),
          _modernField(_medicalCtrl, 'MEDICAL CONDITIONS', Icons.health_and_safety_outlined, isDark, maxLines: 2),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'UPDATE PERSONAL DATA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernField(TextEditingController ctrl, String label, IconData icon, bool isDark, {int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, child) {
        final bool isEmpty = value.text.trim().isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
                ),
                if (isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('EMPTY', style: TextStyle(color: Colors.redAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFD32F2F).withOpacity(0.5)),
                ),
              ),
            ),
          ],
        );
      }
    );
  }
Widget _buildDocumentsSection(bool isDark) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
    ),
    child: Column(
      children: [
        _docRow(Icons.badge_outlined, 'PASSPORT / ID PROOF', _userData?['passport_url'], 'passport_url', isDark),

        const Divider(height: 20),

        _docRow(Icons.fingerprint_outlined, 'AADHAR CARD', _userData?['aadhar_url'], 'aadhar_url', isDark),

        const Divider(height: 20),

        _docRow(Icons.medical_services_outlined, 'MEDICAL CERTIFICATE', _userData?['medical_certificate_url'], 'medical_certificate_url', isDark),
      ],
    ),
  );
}

  Widget _docRow(IconData icon, String title, String? url, String field, bool isDark) {
  final hasFile = url != null && url.startsWith('http');

  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (hasFile ? Colors.green : Colors.blueGrey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: hasFile ? Colors.green : Colors.blueGrey),
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (hasFile ? Colors.green : Colors.redAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: (hasFile ? Colors.green : Colors.redAccent).withOpacity(0.2)),
              ),
              child: Text(
                hasFile ? 'VERIFIED / UPLOADED' : 'ACTION REQUIRED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: hasFile ? Colors.green : Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),

      IconButton(
        onPressed: () => _replaceDoc(field, title),
        icon: const Icon(Icons.upload_outlined, size: 18),
      ),
    ],
  );
}

  
  Widget _buildSecurityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          _modernField(_passwordController, 'NEW PASSWORD', Icons.lock_outline, isDark),
          const SizedBox(height: 16),
          _modernField(_confirmPasswordController, 'CONFIRM PASSWORD', Icons.lock_reset_outlined, isDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _updateTripPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF475569),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'CHANGE PASSWORD',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      await _client.from('profiles').update({
        'full_name': _nameCtrl.text,
        'phone_number': _phoneCtrl.text,
        'emergency_contact': _emergencyCtrl.text,
        'blood_group': _bloodCtrl.text,
        'medical_info': _medicalCtrl.text,
      }).eq('id', _client.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPDATE FAILED: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

 void _replaceDoc(String field, String title) async {
  final controller = TextEditingController();

  final url = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Text(
              'Add $title',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'Paste document URL here',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 52, // 👈 increase height (try 50–56 range)
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white, // 👈 forces white text + icon
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14, // 👈 slightly bigger text
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  if (url == null || url.isEmpty) return;

  // basic validation (don’t trust users blindly)
  if (!url.startsWith('http')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid URL')),
    );
    return;
  }

  try {
    await _client.from('profiles').update({field: url}).eq(
          'id',
          _client.auth.currentUser!.id,
        );

    _fetchData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document updated')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
}

  Future<void> _updateTripPassword() async {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PASSWORD UPDATED successfully.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PROVISIONING FAILED: $e'), backgroundColor: Colors.red));
    }
  }
}
