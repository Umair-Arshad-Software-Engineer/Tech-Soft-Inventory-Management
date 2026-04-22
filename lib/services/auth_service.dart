// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../config/api_config.dart';
// import '../models/user_model.dart';
//
// class AuthService {
//
//   Future<Map<String, String>> getHeaders() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token');
//
//     return {
//       'Content-Type': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }
//
// // Register - FIXED: Send auth token
//   Future<Map<String, dynamic>> register({
//     required String name,
//     required String email,
//     required String password,
//   }) async {
//     try {
//       final headers = await getHeaders(); // ← was {'Content-Type': 'application/json'}
//
//       final response = await http.post(
//         Uri.parse(ApiConfig.registerUrl),
//         headers: headers,  // ← now includes Bearer token
//         body: jsonEncode({
//           'name': name,
//           'email': email,
//           'password': password,
//         }),
//       );
//
//       print('Register Response: ${response.statusCode} - ${response.body}');
//
//       final data = jsonDecode(response.body);
//
//       if (response.statusCode == 201 && data['success'] == true) {
//         // Don't save the new user's token — caller stays logged in
//         return {'success': true};
//       } else {
//         return {'success': false, 'message': data['message'] ?? 'Registration failed'};
//       }
//     } catch (e) {
//       print('Register Error: $e');
//       return {'success': false, 'message': 'Connection error. Please try again.'};
//     }
//   }
//
//   // Login - Updated
//   Future<Map<String, dynamic>> login({
//     required String email,
//     required String password,
//   })
//   async {
//     try {
//       final response = await http.post(
//         Uri.parse(ApiConfig.loginUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'email': email,
//           'password': password,
//         }),
//       );
//
//       print('Login Response: ${response.statusCode} - ${response.body}');
//
//       final data = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && data['success'] == true) {
//         final user = UserModel.fromJson(data['data']);
//         await _saveToken(user.token!);
//         await _saveUser(user);
//         return {'success': true, 'user': user};
//       } else {
//         return {'success': false, 'message': data['message'] ?? 'Login failed'};
//       }
//     } catch (e) {
//       print('Login Error: $e');
//       return {'success': false, 'message': 'Connection error. Please try again.'};
//     }
//   }
//
//   // Get current user profile
//   Future<Map<String, dynamic>> getProfile() async {
//     try {
//       final headers = await getHeaders();
//
//       final response = await http.get(
//         Uri.parse(ApiConfig.getMeUrl),
//         headers: headers,
//       );
//
//       print('Profile Response: ${response.statusCode} - ${response.body}');
//
//       final data = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && data['success'] == true) {
//         final user = UserModel.fromJson(data['data']);
//         await _saveUser(user); // Update user data
//         return {'success': true, 'user': user};
//       } else {
//         return {'success': false, 'message': data['message'] ?? 'Failed to get profile'};
//       }
//     } catch (e) {
//       print('Profile Error: $e');
//       return {'success': false, 'message': 'Connection error'};
//     }
//   }
//
//   // Logout
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('token');
//     await prefs.remove('user');
//   }
//
//   // Get current user
//   Future<UserModel?> getCurrentUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJson = prefs.getString('user');
//     if (userJson != null) {
//       return UserModel.fromJson(jsonDecode(userJson));
//     }
//     return null;
//   }
//
//   // Check if logged in
//   Future<bool> isLoggedIn() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('token') != null;
//   }
//
//   // Save token
//   Future<void> _saveToken(String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('token', token);
//   }
//
//   // Save user
//   Future<void> _saveUser(UserModel user) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user', jsonEncode(user.toJson()));
//   }
//
//   Future<Map<String, dynamic>> makeAuthenticatedRequest({
//     required String method,
//     required String endpoint,
//     Map<String, dynamic>? body,
//   })
//   async {
//     try {
//       final token = await getToken(); // your existing token getter
//       if (token == null) {
//         return {'success': false, 'message': 'Not authenticated'};
//       }
//
//       final uri = Uri.parse('$baseUrl$endpoint'); // your existing baseUrl
//       late http.Response response;
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token',
//       };
//
//       switch (method.toUpperCase()) {
//         case 'GET':
//           response = await http.get(uri, headers: headers);
//           break;
//         case 'PATCH':
//           response = await http.patch(uri,
//               headers: headers, body: jsonEncode(body));
//           break;
//         case 'PUT':
//           response = await http.put(uri,
//               headers: headers, body: jsonEncode(body));
//           break;
//         case 'DELETE':
//           response = await http.delete(uri, headers: headers);
//           break;
//         default:
//           return {'success': false, 'message': 'Unknown method'};
//       }
//
//       final data = jsonDecode(response.body);
//       return data is Map<String, dynamic>
//           ? data
//           : {'success': false, 'message': 'Invalid response'};
//     } catch (e) {
//       return {'success': false, 'message': 'Request failed: $e'};
//     }
//   }
//
//
// }

// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ADD THIS MISSING METHOD:
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

// Register - FIXED: Send auth token
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final headers = await getHeaders(); // ← was {'Content-Type': 'application/json'}

      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: headers,  // ← now includes Bearer token
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      print('Register Response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Don't save the new user's token — caller stays logged in
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('Register Error: $e');
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  // Login - Updated
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  })
  async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login Response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = UserModel.fromJson(data['data']);
        await _saveToken(user.token!);
        await _saveUser(user);
        return {'success': true, 'user': user};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('Login Error: $e');
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse(ApiConfig.getMeUrl),
        headers: headers,
      );

      print('Profile Response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = UserModel.fromJson(data['data']);
        await _saveUser(user); // Update user data
        return {'success': true, 'user': user};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      print('Profile Error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // Save token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Save user
  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
  }

  Future<Map<String, dynamic>> makeAuthenticatedRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      late http.Response response;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',        // ← ADD THIS
        'Authorization': 'Bearer $token',
      };

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          return {'success': false, 'message': 'Unknown method'};
      }

      // ← ADD THIS BLOCK: check before parsing
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        print('Non-JSON response (${response.statusCode}): ${response.body.substring(0, 200)}');
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}). Check that the endpoint exists: $endpoint',
        };
      }

      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please login again.'};
      }
      if (response.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      }
      if (response.statusCode == 404) {
        return {'success': false, 'message': 'Endpoint not found: $endpoint'};
      }

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic>
          ? data
          : {'success': false, 'message': 'Invalid response format'};

    } catch (e) {
      return {'success': false, 'message': 'Request failed: $e'};
    }
  }
}