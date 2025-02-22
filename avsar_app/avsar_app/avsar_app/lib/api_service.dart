import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = 'http://192.168.2.100:5000';

  /// Kullanıcı giriş yapma
  Future<bool> loginUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // JWT Token'ı kaydet
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token',
            data['token'] ?? ""); // Eğer backend JWT token gönderiyorsa
        await prefs.setString('username', data['username'] ?? "Bilinmiyor");
        await prefs.setString('role', data['role'] ?? "User");

        return true;
      } else {
        print("Giriş başarısız: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Bağlantı hatası: $e");
      return false;
    }
  }

  /// Kullanıcı ekleme
  Future<bool> addUser(String name, String unit, String role, String username,
      String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'unit': unit,
          'role': role,
          'username': username,
          'password': password
        }),
      );

      if (response.statusCode == 201) {
        // 201 Created status code
        print("Kullanıcı başarıyla eklendi.");
        return true;
      } else {
        print("Kullanıcı ekleme başarısız: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Bağlantı hatası: $e");
      return false;
    }
  }

  /// Kullanıcı güncelleme
  Future<bool> updateUser(
      int userId, String name, String unit, String role) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'unit': unit, 'role': role}),
      );

      if (response.statusCode == 200) {
        print("Kullanıcı başarıyla güncellendi.");
        return true;
      } else {
        print("Kullanıcı güncelleme başarısız: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Bağlantı hatası: $e");
      return false;
    }
  }

  /// Kullanıcı silme
  Future<bool> deleteUser(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
      );

      if (response.statusCode == 200) {
        print("Kullanıcı başarıyla silindi.");
        return true;
      } else {
        print("Kullanıcı silme başarısız: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Bağlantı hatası: $e");
      return false;
    }
  }

  /// Kullanıcıları API'den çek
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/'));
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedUsers =
            List<Map<String, dynamic>>.from(
                jsonDecode(utf8.decode(response.bodyBytes)));
        return fetchedUsers;
      } else {
        print("Kullanıcılar yüklenemedi! Hata kodu: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Kullanıcıları çekerken hata oluştu: $e");
      return [];
    }
  }
}
