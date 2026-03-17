import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _avatarController;
  late TextEditingController _emergencyController;
  late TextEditingController _medicalController;
  late TextEditingController _phoneController;
  String _bloodGroup = 'Not Set';
  bool _isSaving = false;

  final List<String> _bloodGroups = ['Not Set', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['full_name']);
    _avatarController = TextEditingController(text: widget.profile['avatar_url']);
    _emergencyController = TextEditingController(text: widget.profile['emergency_contact'] ?? '');
    _medicalController = TextEditingController(text: widget.profile['medical_info'] ?? '');
    _phoneController = TextEditingController(text: widget.profile['phone_number'] ?? '');
    _bloodGroup = widget.profile['blood_group'] ?? 'Not Set';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'avatar_url': _avatarController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'emergency_contact': _emergencyController.text.trim(),
        'medical_info': _medicalController.text.trim(),
        'blood_group': _bloodGroup,
      }).eq('id', user.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        // If columns don't exist, show a helpful message
        if (e.toString().contains('42703')) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('New Features Setup'),
              content: const Text('To use Emergency Contact and Blood Group features, please run the following SQL in your Supabase Editor:\n\nALTER TABLE profiles ADD COLUMN emergency_contact TEXT, ADD COLUMN blood_group TEXT, ADD COLUMN medical_info TEXT;'),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  backgroundImage: _avatarController.text.isNotEmpty ? NetworkImage(_avatarController.text) : null,
                  child: _avatarController.text.isEmpty ? const Icon(Icons.person, size: 40) : null,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildTextField('Full Name', _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildTextField('Avatar URL', _avatarController, Icons.link),
            const SizedBox(height: 20),
            _buildTextField('Phone Number', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 30),
            const Text('Safety Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            const SizedBox(height: 10),
            _buildTextField('Emergency Contact (Number)', _emergencyController, Icons.phone_android, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            const Text('Blood Group', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor), 
                borderRadius: BorderRadius.circular(10)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _bloodGroup,
                  isExpanded: true,
                  onChanged: (val) => setState(() => _bloodGroup = val!),
                  items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField('Medical Info (Allergies, etc.)', _medicalController, Icons.medical_services_outlined, maxLines: 3),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return FadeInUp(
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }
}
