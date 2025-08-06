import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final storage = const FlutterSecureStorage();
  late String baseUrl;

  ApiService() {
    baseUrl = dotenv.env['BASE_URL'] ?? '';
  }

  Future<bool> loginUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'token', value: data['access_token']);
        await storage.write(key: 'username', value: data['username'] ?? "Bilinmiyor");
        await storage.write(key: 'role', value: data['role'] ?? "User");
        await storage.write(key: 'email', value: data['email'] ?? "");
        await storage.write(key: 'unit', value: data['unit'] ?? "");

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

  Future<bool> addUser(String name, String unit, String role, String username,
      String password) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'name': name,
          'unit': unit,
          'role': role,
          'username': username,
          'password': password
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print("Kullanıcı ekleme hatası: $e");
      return false;
    }
  }

  Future<bool> updateUser(
      String username, String name, String unit, String role) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.put(
        Uri.parse('$baseUrl/users/$username'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({'name': name, 'unit': unit, 'role': role}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Kullanıcı güncelleme hatası: $e");
      return false;
    }
  }

  Future<bool> deleteUser(String username) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$username'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Kullanıcı silme hatası: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
            jsonDecode(utf8.decode(response.bodyBytes)));
      }
      return [];
    } catch (e) {
      print("Kullanıcıları çekerken hata: $e");
      return [];
    }
  }
}
