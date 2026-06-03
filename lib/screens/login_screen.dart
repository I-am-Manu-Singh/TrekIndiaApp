import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthFlowStatus { login, signup, verify, setPassword, forgotPassword }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  AuthFlowStatus _currentStatus = AuthFlowStatus.login;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _loginWithPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        // Silent Repair for Name on Login
        final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', res.user!.id).maybeSingle();
        String? name = profile?['full_name'];
        if (name == null || name.trim().isEmpty || name == 'Explorer') {
          name = res.user!.userMetadata?['full_name'] ?? res.user!.email?.split('@')[0] ?? 'Explorer';
          await Supabase.instance.client.from('profiles').update({'full_name': name}).eq('id', res.user!.id);
        }
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Use email prefix as fallback name if user didn't enter one
      final String derivedName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : _emailController.text.trim().split('@').first;

      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
        shouldCreateUser: true,
        data: _currentStatus == AuthFlowStatus.signup
            ? {'full_name': derivedName}
            : null,
      );
      if (mounted) {
        setState(() => _currentStatus = AuthFlowStatus.verify);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email!'), backgroundColor: Colors.green));
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.email, // Use email instead of magiclink for 6-digit OTP
      );
      // Once verified, Supabase creates a session. We now show Set Password.
      if (mounted) setState(() => _currentStatus = AuthFlowStatus.setPassword);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP: ${e.message}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishAndSetPassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      
      if (res.user != null) {
        // Silent Repair for Name on Password Setup
        final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', res.user!.id).maybeSingle();
        String? name = profile?['full_name'];
        if (name == null || name.trim().isEmpty || name == 'Explorer') {
          name = res.user!.userMetadata?['full_name'] ?? res.user!.email?.split('@')[0] ?? 'Explorer';
          await Supabase.instance.client.from('profiles').update({'full_name': name}).eq('id', res.user!.id);
        }
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email to recover access')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'io.supabase.trekbooking://login-callback/',
      );
      if (mounted) {
        setState(() => _currentStatus = AuthFlowStatus.login);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent to your email.'), backgroundColor: Colors.green));
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.trekbooking://login-callback/',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  FadeInDown(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.terrain_rounded,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTitle(),
                  const SizedBox(height: 40),
                  
                  if (_currentStatus == AuthFlowStatus.login) _buildLoginForm(),
                  if (_currentStatus == AuthFlowStatus.signup) _buildSignupForm(),
                  if (_currentStatus == AuthFlowStatus.verify) _buildVerifyForm(),
                  if (_currentStatus == AuthFlowStatus.setPassword) _buildSetPasswordForm(),
                  if (_currentStatus == AuthFlowStatus.forgotPassword) _buildForgotPasswordForm(),
                  
                  const SizedBox(height: 40),
                  if (_currentStatus == AuthFlowStatus.login || _currentStatus == AuthFlowStatus.signup) ...[
                    FadeInUp(
                      child: Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                        label: Text('Continue with Google', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    String title = "trekwithmussafirr";
    String subtitle = "Your gateway to the Himalayas";
    
    if (_currentStatus == AuthFlowStatus.signup) {
      title = "New Account";
      subtitle = "Verify your email to begin";
    } else if (_currentStatus == AuthFlowStatus.verify) {
      title = "Verify OTP";
      subtitle = "Enter code sent to ${_emailController.text}";
    } else if (_currentStatus == AuthFlowStatus.setPassword) {
      title = "Secure Account";
      subtitle = "Set a password for future logins";
    } else if (_currentStatus == AuthFlowStatus.forgotPassword) {
      title = "Recover Access";
      subtitle = "Send a reset link to your email";
    }

    return FadeInDown(
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(_emailController, 'Email', Icons.email_outlined),
        const SizedBox(height: 20),
        _buildTextField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 30),
        _buildPrimaryButton('Login', _loginWithPassword),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _currentStatus = AuthFlowStatus.forgotPassword),
          child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _currentStatus = AuthFlowStatus.signup),
          child: Text("New User? Create Account", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      children: [
        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 20),
        _buildTextField(_emailController, 'Enter Email for OTP', Icons.email_outlined),
        const SizedBox(height: 30),
        _buildPrimaryButton('Send Verification Code', _sendOtp),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _currentStatus = AuthFlowStatus.login),
          child: const Text("Back to Password Login", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildVerifyForm() {
    return Column(
      children: [
        _buildTextField(_otpController, '6-Digit Code', Icons.verified_user_outlined, keyboardType: TextInputType.number),
        const SizedBox(height: 30),
        _buildPrimaryButton('Verify OTP', _verifyOtp),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _currentStatus = AuthFlowStatus.signup),
          child: const Text("Resend Code", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildSetPasswordForm() {
    return Column(
      children: [
        _buildTextField(_passwordController, 'Choose Password', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 20),
        _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 30),
        _buildPrimaryButton('Finish & Start Exploring', _finishAndSetPassword),
      ],
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      children: [
        _buildTextField(_emailController, 'Recovery Email', Icons.email_outlined),
        const SizedBox(height: 30),
        _buildPrimaryButton('Send Reset Link', _resetPassword),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _currentStatus = AuthFlowStatus.login),
          child: const Text("Back to Login", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    return FadeInUp(
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
