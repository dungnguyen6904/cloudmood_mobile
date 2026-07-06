import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  AuthService._internal() {
    _loadLocalSession();
    // Delay listener registration to ensure Supabase.initialize() has completed in main()
    Future.microtask(() {
      try {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          if (session == null) {
            // Google Sign-In signed out
            if (currentUser.value != null && currentUser.value!.password.isEmpty) {
              currentUser.value = null;
              _clearLocalSession();
            }
          } else {
            final email = session.user.email;
            if (email != null) {
              final profile = await _fetchUserProfile(email);
              if (profile != null) {
                currentUser.value = profile;
                await _saveLocalSession(profile);
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
                if (newProfile != null) {
                  currentUser.value = newProfile;
                  await _saveLocalSession(newProfile);
                }
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

  // Register a new user with public.User table directly (Bypassing Supabase Auth email verification)
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // 1. Check if email already exists in User table
      final existingUser = await _fetchUserProfile(normalizedEmail);
      if (existingUser != null) {
        return {'success': false, 'message': 'Email này đã được đăng ký bởi tài khoản khác.'};
      }
      
      // 2. Insert profile record into public.User table directly
      final profile = await _createUserProfile(
        fullName: fullName.trim(),
        email: normalizedEmail,
        password: password,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      );
      
      if (profile != null) {
        currentUser.value = profile;
        await _saveLocalSession(profile);
        return {'success': true, 'message': 'Đăng ký tài khoản thành công!'};
      } else {
        return {'success': false, 'message': 'Đăng ký thất bại. Vui lòng thử lại.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối cơ sở dữ liệu: $e'};
    }
  }

  // Login with email and password (Bypassing Supabase Auth email verification)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // Query table User directly for match
      final response = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', normalizedEmail)
          .eq('password', password)
          .maybeSingle();
      
      if (response == null) {
        return {'success': false, 'message': 'Email hoặc mật khẩu không chính xác.'};
      }
      
      final profile = UserModel.fromMap(response);
      currentUser.value = profile;
      await _saveLocalSession(profile);
      return {'success': true, 'message': 'Đăng nhập thành công!'};
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

  // Update user profile in public.User table
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
          
      // Update metadata in Auth server optionally (in case logged in via Google)
      if (currentUser.value!.password.isEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'full_name': fullName,
                'avatar_url': avatarUrl,
              },
            ),
          );
        } catch (e) {
          debugPrint('Could not update metadata: $e');
        }
      }
      
      final updatedUser = UserModel.fromMap(response);
      currentUser.value = updatedUser;
      await _saveLocalSession(updatedUser);
      return true;
    } catch (e) {
      debugPrint('Error updating profile in Supabase: $e');
      return false;
    }
  }

  // Change password inside User table directly
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser.value == null) {
      return {'success': false, 'message': 'Chưa đăng nhập.'};
    }
    
    try {
      final email = currentUser.value!.email;
      final currentDbPassword = currentUser.value!.password;
      
      if (currentPassword != currentDbPassword) {
        return {'success': false, 'message': 'Mật khẩu hiện tại không chính xác.'};
      }
      
      // Update in table User password column
      final response = await Supabase.instance.client
          .from('User')
          .update({'password': newPassword})
          .eq('email', email)
          .select()
          .single();
          
      final updatedUser = UserModel.fromMap(response);
      currentUser.value = updatedUser;
      await _saveLocalSession(updatedUser);
      
      return {'success': true, 'message': 'Đổi mật khẩu thành công!'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đổi mật khẩu: $e'};
    }
  }

  static const String _sessionKey = 'logged_in_user';

  // Save session to local storage
  Future<void> _saveLocalSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toMap());
      await prefs.setString(_sessionKey, userJson);
    } catch (e) {
      debugPrint('Error saving local session: $e');
    }
  }

  // Load session from local storage
  Future<void> _loadLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_sessionKey);
      if (userJson != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        final email = userMap['email'] as String;
        final latestProfile = await _fetchUserProfile(email);
        if (latestProfile != null) {
          currentUser.value = latestProfile;
          await _saveLocalSession(latestProfile);
        } else {
          currentUser.value = UserModel.fromMap(userMap);
        }
      }
    } catch (e) {
      debugPrint('Error loading local session: $e');
    }
  }

  // Clear local session from storage
  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('Error clearing local session: $e');
    }
  }

  // Logout session
  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error logging out from Supabase: $e');
    }
    await _clearLocalSession();
    currentUser.value = null;
  }
}
