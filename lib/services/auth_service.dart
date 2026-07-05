import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  AuthService._internal() {
    // Delay listener registration to ensure Supabase.initialize() has completed in main()
    Future.microtask(() {
      try {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          if (session == null) {
            currentUser.value = null;
          } else {
            final email = session.user.email;
            if (email != null) {
              final profile = await _fetchUserProfile(email);
              if (profile != null) {
                currentUser.value = profile;
              } else {
                final rawName = session.user.userMetadata?['full_name'] ?? 'Google User';
                final avatarUrl = session.user.userMetadata?['avatar_url'] ?? 
                    'https://images.unsplash.com/photo-1607990283143-e81e7a2c93ab?w=200&auto=format&fit=crop&q=80';
                
                final newProfile = await _createUserProfile(
                  fullName: rawName,
                  email: email,
                  password: '',
                  avatarUrl: avatarUrl,
                );
                currentUser.value = newProfile;
              }
            }
          }
        });
      } catch (e) {
        debugPrint('Supabase is not initialized yet in microtask: $e');
      }
    });
  }

  // Active session notifier
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  // Fetch user details from table User matching email
  Future<UserModel?> _fetchUserProfile(String email) async {
    try {
      final response = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (response != null) {
        return UserModel.fromMap(response);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }

  // Helper: Create a record inside the public.User table
  Future<UserModel?> _createUserProfile({
    required String fullName,
    required String email,
    required String password,
    required String avatarUrl,
  }) async {
    try {
      final data = {
        'fullName': fullName,
        'email': email,
        'password': password, // Mapped for your custom schema
        'avatar': avatarUrl,
        'role': false, // default regular member
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final response = await Supabase.instance.client
          .from('User')
          .insert(data)
          .select()
          .single();
          
      return UserModel.fromMap(response);
    } catch (e) {
      debugPrint('Error creating user profile in table: $e');
    }
    return null;
  }

  // Register a new user with Supabase Auth & public.User table
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // 1. Sign up user via Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': fullName},
      );
      
      if (authResponse.user == null) {
        return {'success': false, 'message': 'Đăng ký thất bại trên Auth server.'};
      }
      
      // 2. Insert profile record into public.User table
      final profile = await _createUserProfile(
        fullName: fullName.trim(),
        email: normalizedEmail,
        password: password,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      );
      
      if (profile != null) {
        currentUser.value = profile;
        return {'success': true, 'message': 'Đăng ký tài khoản thành công!'};
      } else {
        return {
          'success': true,
          'message': 'Đăng ký thành công! Hãy kiểm tra hòm thư để xác nhận email kích hoạt.'
        };
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối cơ sở dữ liệu: $e'};
    }
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // 1. Authenticate with Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      
      if (authResponse.user == null) {
        return {'success': false, 'message': 'Đăng nhập không thành công.'};
      }
      
      // 2. Retrieve corresponding row from table User
      final profile = await _fetchUserProfile(normalizedEmail);
      if (profile != null) {
        currentUser.value = profile;
        return {'success': true, 'message': 'Đăng nhập thành công!'};
      } else {
        // If table User doesn't have it (e.g. registered via console), create record fallback
        final newProfile = await _createUserProfile(
          fullName: authResponse.user!.userMetadata?['full_name'] ?? 'User Member',
          email: normalizedEmail,
          password: password,
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        );
        currentUser.value = newProfile;
        return {'success': true, 'message': 'Đăng nhập thành công (Đã khởi tạo hồ sơ mới)!'};
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('Invalid login credentials')) {
        msg = 'Email hoặc mật khẩu không chính xác.';
      } else if (msg.contains('Email not confirmed')) {
        msg = 'Tài khoản chưa được xác nhận email. Vui lòng kích hoạt tài khoản trong hộp thư.';
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối cơ sở dữ liệu: $e'};
    }
  }

  // Google Sign-In (Official Redirect flow for web and mobile oauth)
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final success = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      return {'success': success, 'message': 'Đang kết nối tới Google...'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi OAuth: $e'};
    }
  }

  // Update user profile in both public.User table and Auth metadata
  Future<bool> updateProfile({
    required String fullName,
    required String avatarUrl,
  }) async {
    if (currentUser.value == null) return false;
    
    try {
      final email = currentUser.value!.email;
      
      // Update database row
      final response = await Supabase.instance.client
          .from('User')
          .update({
            'fullName': fullName,
            'avatar': avatarUrl,
          })
          .eq('email', email)
          .select()
          .single();
          
      // Update metadata in Auth server
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName,
            'avatar_url': avatarUrl,
          },
        ),
      );
      
      currentUser.value = UserModel.fromMap(response);
      return true;
    } catch (e) {
      debugPrint('Error updating profile in Supabase: $e');
      return false;
    }
  }

  // Change password inside Supabase Auth
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser.value == null) {
      return {'success': false, 'message': 'Chưa đăng nhập.'};
    }
    
    try {
      final email = currentUser.value!.email;
      
      // Update user password in Auth server
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      // Sync it in table User password column
      await Supabase.instance.client
          .from('User')
          .update({'password': newPassword})
          .eq('email', email);
          
      final updatedUser = currentUser.value!.copyWith(password: newPassword);
      currentUser.value = updatedUser;
      
      return {'success': true, 'message': 'Đổi mật khẩu thành công!'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đổi mật khẩu: $e'};
    }
  }

  // Logout session
  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error logging out from Supabase: $e');
    }
    currentUser.value = null;
  }
}
