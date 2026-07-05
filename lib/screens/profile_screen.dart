import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import 'login_screen.dart';

class CloudmoodProfileScreen extends StatefulWidget {
  const CloudmoodProfileScreen({super.key});

  @override
  State<CloudmoodProfileScreen> createState() => _CloudmoodProfileScreenState();
}

class _CloudmoodProfileScreenState extends State<CloudmoodProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // Settings mock states
  bool _notifEnabled = true;
  bool _darkModeEnabled = false;

  // Preset avatar options for users to choose from
  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80', // Guy
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80', // Girl
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200&auto=format&fit=crop&q=80', // Retro guy
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', // Girl photographer
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80', // Beard man
    'https://images.unsplash.com/photo-1607990283143-e81e7a2c93ab?w=200&auto=format&fit=crop&q=80', // Traveler guy
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Opens Edit Profile Bottom Sheet
  void _showEditProfileSheet(BuildContext context, String currentName, String currentAvatar) {
    final nameController = TextEditingController(text: currentName);
    String selectedAvatar = currentAvatar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Text input for Name
                  TextField(
                    controller: nameController,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Họ và tên',
                      prefixIcon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Selected avatar view & header
                  const Text(
                    'Chọn ảnh đại diện mẫu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 12),
                  
                  // Grid of preset avatars
                  SizedBox(
                    height: 140,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _avatarPresets.length,
                      itemBuilder: (context, index) {
                        final avatarUrl = _avatarPresets[index];
                        final isSelected = selectedAvatar == avatarUrl;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedAvatar = avatarUrl;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final updated = await _authService.updateProfile(
                          fullName: nameController.text.trim(),
                          avatarUrl: selectedAvatar,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          if (updated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hồ sơ đã được cập nhật thành công!'),
                                backgroundColor: AppTheme.green,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Show Change Password Dialog
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Đổi mật khẩu',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      prefixIcon: Icons.lock_open_rounded,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Mật khẩu mới',
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập mật khẩu mới.';
                      if (v.length < 6) return 'Mật khẩu mới ít nhất từ 6 kí tự.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmNewPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Xác nhận mật khẩu mới',
                      prefixIcon: Icons.lock_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Xác nhận mật khẩu mới.';
                      if (v != newPasswordController.text) return 'Mật khẩu mới không khớp.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.subtitleText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final result = await _authService.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (result['success'] as bool) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] as String), backgroundColor: AppTheme.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] as String), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Đổi mật khẩu'),
            ),
          ],
        );
      },
    );
  }

  // Logout confirmation dialog
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Cloudmood?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.subtitleText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _authService.logout();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đăng xuất thành công!'), backgroundColor: AppTheme.primary),
                );
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _authService.currentUser,
      builder: (context, user, child) {
        if (user == null) {
          return _buildGuestWelcomeScreen(context);
        }
        return ProfileDashboard(
          user: user,
          onEditProfile: _showEditProfileSheet,
          onChangePassword: _showChangePasswordDialog,
          onLogout: _showLogoutConfirmDialog,
        );
      },
    );
  }

  // 1. GUEST WELCOME SCREEN (When user is not logged in)
  Widget _buildGuestWelcomeScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo image
              Image.asset(
                'assets/images/logo-cloudmood.png',
                height: 70,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.cloud_rounded, size: 70, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              const Text('cloudmood', style: AppTheme.brandLogoStyle),
              const SizedBox(height: 16),
              const Text(
                'Lưu giữ và chia sẻ hành trình du lịch của bạn. Khám phá các điểm đến được gợi ý tự động dựa trên tâm trạng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.subtitleText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 48),

              // Sign In Button
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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CloudmoodLoginScreen()),
                    );
                  },
                  child: const Text(
                    'Đăng nhập tài khoản',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sign Up / Browse as guest
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản? ', style: TextStyle(color: AppTheme.subtitleText)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CloudmoodLoginScreen()),
                      );
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. LOGGED IN PROFILE DASHBOARD
class ProfileDashboard extends StatefulWidget {
  final UserModel user;
  final Function(BuildContext, String, String) onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const ProfileDashboard({
    super.key,
    required this.user,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _itineraries = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  // Local settings switches
  bool _notifEnabled = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    DatabaseService.refreshTrigger.addListener(_loadData);
  }

  @override
  void dispose() {
    DatabaseService.refreshTrigger.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final itineraries = await DatabaseService().fetchUserItineraries(widget.user.id);
    final reviews = await DatabaseService().fetchUserReviews(widget.user.id);
    
    if (!mounted) return;
    setState(() {
      _itineraries = itineraries;
      _reviews = reviews;
      _isLoading = false;
    });
  }

  // Calculate Total Budget from all itineraries
  int get _totalBudget {
    int sum = 0;
    for (var itin in _itineraries) {
      final b = itin['budget'];
      if (b != null) {
        sum += (b is num) ? b.toInt() : (int.tryParse(b.toString()) ?? 0);
      }
    }
    return sum;
  }

  // Helper budget formatter: e.g. 5000000 -> 5Tr
  String _formatBudget(int budget) {
    if (budget >= 1000000) {
      double m = budget / 1000000.0;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}Tr';
    } else if (budget >= 1000) {
      double k = budget / 1000.0;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
    }
    return '$budget';
  }

  // Show Bottom Sheet to Create Itinerary
  void _showCreateItinerarySheet(BuildContext context) {
    final titleController = TextEditingController();
    final daysController = TextEditingController(text: '3');
    final budgetController = TextEditingController(text: '3000000');
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tạo hành trình mới',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: titleController,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Tên chuyến đi (ví dụ: Khám phá Phú Quốc)',
                      prefixIcon: Icons.title_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppTheme.subtitleText),
                          const SizedBox(width: 10),
                          Text(
                            'Khởi hành: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 14, color: AppTheme.darkText),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: AppTheme.subtitleText),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysController,
                          keyboardType: TextInputType.number,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Số ngày',
                            prefixIcon: Icons.today_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: budgetController,
                          keyboardType: TextInputType.number,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Ngân sách (đ)',
                            prefixIcon: Icons.monetization_on_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên chuyến đi!')),
                          );
                          return;
                        }
                        
                        final days = int.tryParse(daysController.text) ?? 3;
                        final budget = int.tryParse(budgetController.text) ?? 1000000;
                        
                        final result = await DatabaseService().createUserItinerary(
                          userId: widget.user.id,
                          title: title,
                          startDate: selectedDate,
                          days: days,
                          budget: budget,
                        );
                        
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã thêm hành trình mới thành công!'),
                                backgroundColor: AppTheme.green,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Lưu hành trình', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Star Rating Bar builder
  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(const Icon(Icons.star_rounded, color: AppTheme.amber, size: 16));
      } else {
        stars.add(const Icon(Icons.star_border_rounded, color: AppTheme.border, size: 16));
      }
    }
    return Row(children: stars);
  }

  @override
  Widget build(BuildContext context) {
    final String joinDate = '${widget.user.createdAt.day}/${widget.user.createdAt.month}/${widget.user.createdAt.year}';
    final String roleText = widget.user.role ? 'Quản trị viên' : 'Thành viên PRO';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hồ sơ cá nhân', style: AppTheme.sectionTitleStyle),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 28),
                            onPressed: () => widget.onEditProfile(context, widget.user.fullName, widget.user.avatar ?? ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // User Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.premiumCardDecoration(),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary.withAlpha(100), width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: widget.user.avatar != null && widget.user.avatar!.isNotEmpty
                                    ? Image.network(
                                        widget.user.avatar!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.person, size: 40, color: AppTheme.subtitleText),
                                      )
                                    : const Icon(Icons.person, size: 40, color: AppTheme.subtitleText),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.user.fullName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(widget.user.email, style: const TextStyle(fontSize: 13, color: AppTheme.subtitleText)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryPeach,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primary.withAlpha(80),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          roleText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ID: #${widget.user.id} · $joinDate',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.subtitleText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Database Statistics
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        decoration: AppTheme.premiumCardDecoration(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ProfileStatWidget(
                              count: _isLoading ? '...' : '${_itineraries.length}',
                              label: 'Chuyến đi',
                            ),
                            _ProfileStatWidget(
                              count: _isLoading ? '...' : '${_reviews.length}',
                              label: 'Đánh giá',
                            ),
                            _ProfileStatWidget(
                              count: _isLoading ? '...' : _formatBudget(_totalBudget),
                              label: 'Tổng ngân sách',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.subtitleText,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: 'Hành trình'),
                      Tab(text: 'Đánh giá'),
                      Tab(text: 'Cài đặt'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildItinerariesTab(),
              _buildReviewsTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: ITINERARIES FROM DB
  Widget _buildItinerariesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    
    if (_itineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.luggage_outlined, size: 64, color: AppTheme.primary.withAlpha(120)),
              const SizedBox(height: 12),
              const Text(
                'Chưa có hành trình nào',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy bắt đầu kỳ nghỉ tuyệt vời của bạn bằng cách thêm một chuyến đi mới ngay hôm nay!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tạo chuyến đi đầu tiên', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showCreateItinerarySheet(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _itineraries.length,
      itemBuilder: (context, index) {
        final item = _itineraries[index];
        final budgetFormatted = _formatBudget((item['budget'] as num?)?.toInt() ?? 0);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300&auto=format&fit=crop&q=80',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'Chuyến đi không tên',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['days']} ngày · Bắt đầu: ${item['startDate']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.subtitleText),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPeach,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Chi phí: $budgetFormatted',
                        style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: REVIEWS FROM DB
  Widget _buildReviewsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    
    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rate_review_outlined, size: 64, color: AppTheme.primary.withAlpha(120)),
              const SizedBox(height: 12),
              const Text(
                'Chưa có đánh giá nào',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ghé thăm mục Khách sạn hoặc gợi ý để viết những dòng đánh giá trải nghiệm đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final item = _reviews[index];
        final place = item['Place'] as Map<String, dynamic>?;
        final placeName = place != null ? place['name'] as String : 'Địa điểm du lịch';
        final placeImage = place != null ? place['image'] as String : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=200';
        final rating = (item['rating'] as num?)?.toDouble() ?? 5.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  placeImage,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 70, height: 70, color: Colors.grey[200]),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 4),
                    _buildStarRating(rating),
                    const SizedBox(height: 6),
                    Text(
                      item['comment'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ngày đăng: ${item['publishedDate'] ?? ""}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.subtitleText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: SYSTEM PREFERENCE SETTINGS
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Section: Account
        const Text(
          'TÀI KHOẢN',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.subtitleText, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.password_rounded,
                iconColor: Colors.blueAccent,
                title: 'Đổi mật khẩu',
                onTap: widget.onChangePassword,
              ),
              const Divider(height: 1, thickness: 0.5),
              _buildSettingTile(
                icon: Icons.notifications_active_rounded,
                iconColor: AppTheme.amber,
                title: 'Thông báo ứng dụng',
                trailing: Switch(
                  value: _notifEnabled,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _notifEnabled = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: System Preference
        const Text(
          'TÙY CHỌN HỆ THỐNG',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.subtitleText, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.purple,
                title: 'Chế độ tối (Bản thử nghiệm)',
                trailing: Switch(
                  value: _darkModeEnabled,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _darkModeEnabled = val;
                    });
                  },
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              _buildSettingTile(
                icon: Icons.translate_rounded,
                iconColor: Colors.teal,
                title: 'Ngôn ngữ',
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tiếng Việt', style: TextStyle(fontSize: 13, color: AppTheme.subtitleText)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black26),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Log Out Button
        Container(
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: _buildSettingTile(
            icon: Icons.logout_rounded,
            iconColor: Colors.redAccent,
            title: 'Đăng xuất tài khoản',
            titleColor: Colors.redAccent,
            onTap: widget.onLogout,
          ),
        ),
      ],
    );
  }

  // Setting tile helper
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color titleColor = AppTheme.darkText,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
      ),
    );
  }
}

// Sub-widget for profile counter statistics
class _ProfileStatWidget extends StatelessWidget {
  final String count;
  final String label;

  const _ProfileStatWidget({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.subtitleText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Persistent Header Delegate for beautiful pinned tabs
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
