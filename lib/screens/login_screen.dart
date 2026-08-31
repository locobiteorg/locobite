import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showOtp = false;
  bool _loading = false;
  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  int _resendTimer = 30;

  void _loginAndProceed() async {
    final otpCode = _otpCtrls.map((c) => c.text).join();
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // Verify OTP via Supabase
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        email: _emailCtrl.text.trim(),
        token: otpCode,
      );

      if (res.user != null) {
        // Authenticate with our Go Backend (using email as the unique identifier)
        await ApiService.login(_emailCtrl.text.trim());
        if (mounted) {
          _goHome();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    while (mounted && _resendTimer > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendTimer--);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showOtp ? _buildOtpStep() : _buildPhoneStep(),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Padding(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(AppStrings.appName,
            style: GoogleFonts.nunito(
              fontSize: 32, fontWeight: FontWeight.w900,
              color: AppColors.primary, letterSpacing: -1,
            )),
          const SizedBox(height: 4),
          Text('Find the best bites at every station',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMAIL ADDRESS',
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.muted, letterSpacing: 1.5,
                  )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 20, color: AppColors.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          hintStyle: GoogleFonts.nunito(
                            color: AppColors.muted.withOpacity(0.5)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.primaryLight, thickness: 2),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 24),

          _loading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _PrimaryButton(
                  label: 'Get OTP',
                  color: AppColors.amber,
                  onTap: () async {
                    if (_emailCtrl.text.isEmpty || !_emailCtrl.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid email address')),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      await Supabase.instance.client.auth.signInWithOtp(
                        email: _emailCtrl.text.trim(),
                      );
                      setState(() {
                        _showOtp = true;
                        _resendTimer = 30;
                        _startTimer();
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to send OTP: $e')),
                      );
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.primaryLight),
          const SizedBox(height: 12),

          Text('Scanning a QR at the station?',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: Text('Continue via QR Scan',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primaryLight, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Padding(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _showOtp = false),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('Verify OTP',
            style: GoogleFonts.nunito(
              fontSize: 26, fontWeight: FontWeight.w900,
              color: AppColors.foreground,
            )),
          const SizedBox(height: 4),
          RichText(text: TextSpan(
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.muted),
            children: [
              const TextSpan(text: 'OTP sent to '),
              TextSpan(text: _emailCtrl.text,
                style: const TextStyle(fontWeight: FontWeight.w800,
                  color: AppColors.foreground)),
            ],
          )),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => SizedBox(
              width: 46, height: 56,
              child: TextField(
                controller: _otpCtrls[i],
                focusNode: _otpFocus[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    FocusScope.of(context).requestFocus(_otpFocus[i + 1]);
                  }
                },
                style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )),
          ),

          const SizedBox(height: 32),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _PrimaryButton(label: 'Verify & Continue', color: AppColors.primary, onTap: _loginAndProceed),
          const SizedBox(height: 16),

          Center(child: _resendTimer > 0
            ? Text('Resend OTP in 0:${_resendTimer.toString().padLeft(2, '0')}',
                style: GoogleFonts.nunito(color: AppColors.muted, fontWeight: FontWeight.w600))
            : TextButton(
                onPressed: () => setState(() { _resendTimer = 30; _startTimer(); }),
                child: Text('Resend OTP',
                  style: GoogleFonts.nunito(color: AppColors.amber, fontWeight: FontWeight.w800)),
              )),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        shadowColor: color.withOpacity(0.4),
      ),
      child: Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900)),
    );
  }
}
