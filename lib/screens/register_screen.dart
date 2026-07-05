import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class CloudmoodRegisterScreen extends StatefulWidget {
  const CloudmoodRegisterScreen({super.key});

  @override
  State<CloudmoodRegisterScreen> createState() => _CloudmoodRegisterScreenState();
}

class _CloudmoodRegisterScreenState extends State<CloudmoodRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Password strength variables
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;
  double _passwordStrengthPercent = 0.0;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_checkPasswordStrength);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Visual password strength calculator
  void _checkPasswordStrength() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
        _passwordStrengthPercent = 0.0;
      });
      return;
    }

    if (pwd.length < 6) {
      setState(() {
        _passwordStrength = 'Mật khẩu yếu (Ít nhất 6 ký tự)';
        _passwordStrengthColor = Colors.redAccent;
        _passwordStrengthPercent = 0.33;
      });
      return;
    }

    // Check complexity
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(pwd);
    final hasDigits = RegExp(r'[0-9]').hasMatch(pwd);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd);

    if (hasLetters && hasDigits && hasSpecial && pwd.length >= 8) {
      setState(() {
        _passwordStrength = 'Mật khẩu mạnh';
        _passwordStrengthColor = AppTheme.green;
        _passwordStrengthPercent = 1.0;
      });
    } else if (hasLetters && hasDigits) {
      setState(() {
        _passwordStrength = 'Mật khẩu trung bình';
        _passwordStrengthColor = AppTheme.amber;
        _passwordStrengthPercent = 0.66;
      });
    } else {
      setState(() {
        _passwordStrength = 'Mật khẩu yếu (Nên thêm số và ký tự)';
        _passwordStrengthColor = Colors.redAccent;
        _passwordStrengthPercent = 0.33;
      });
    }
  }

  // Handle register submission
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với điều khoản sử dụng và chính sách bảo mật.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final response = await _authService.register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success'] as bool) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: AppTheme.green,
          ),
        );
        // Pop register and pop login to land back in Profile authenticated
        Navigator.of(context)..pop()..pop(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-cloudmood.png',
                    height: 50,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.cloud_rounded, size: 50, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text('cloudmood', style: AppTheme.brandLogoStyle),
                  const SizedBox(height: 24),

                  // Registration Card
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: AppTheme.premiumCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đăng ký tài khoản mới',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                        ),
                        const SizedBox(height: 16),

                        // Full Name Input
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Họ và tên',
                            prefixIcon: Icons.person_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập họ tên.';
                            }
                            if (value.trim().length < 2) {
                              return 'Họ tên phải có ít nhất 2 ký tự.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Email Input
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Địa chỉ email',
                            prefixIcon: Icons.email_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập email.';
                            }
                            final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!regex.hasMatch(value.trim())) {
                              return 'Định dạng email không hợp lệ.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Input
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Mật khẩu',
                            prefixIcon: Icons.lock_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppTheme.subtitleText,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu.';
                            }
                            if (value.length < 6) {
                              return 'Mật khẩu phải dài từ 6 ký tự trở lên.';
                            }
                            return null;
                          },
                        ),
                        
                        // Password Strength Bar
                        if (_passwordStrength.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _passwordStrengthPercent,
                                    backgroundColor: Colors.grey[200],
                                    color: _passwordStrengthColor,
                                    minHeight: 5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _passwordStrength,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _passwordStrengthColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Confirm Password Input
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Xác nhận mật khẩu',
                            prefixIcon: Icons.lock_clock_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppTheme.subtitleText,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu.';
                            }
                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Terms and Conditions checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreeToTerms,
                                activeColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Tôi đồng ý với Điều khoản sử dụng dịch vụ và Chính sách bảo mật của Cloudmood.',
                                style: TextStyle(fontSize: 12, color: AppTheme.subtitleText, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                              shadowColor: AppTheme.primary.withAlpha(80),
                            ),
                            onPressed: _isLoading ? null : _handleRegister,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Đăng ký tài khoản',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Already have account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(color: AppTheme.subtitleText, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Đăng nhập ngay',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
