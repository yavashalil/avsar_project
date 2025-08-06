import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class UserAddScreen extends StatefulWidget {
  const UserAddScreen({super.key});

  @override
  State<UserAddScreen> createState() => _UserAddScreenState();
}

class _UserAddScreenState extends State<UserAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedUnit = 'Muhasebe';
  String _selectedRole = 'User';
  late String baseUrl;

  final List<String> units = [
    'Muhasebe',
    'Satin Alma',
    'Finans',
    'Bilgi Islem',
    'Satis',
    'Kalite',
    'Lojistik',
    'Genel Mudur',
    'Fabrika Muduru'
  ];

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
  }

  bool _validatePassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  bool _validateEmail(String email) {
    return RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(email);
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

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
          "name": _nameController.text.trim(),
          "username": _usernameController.text.trim(),
          "password": _passwordController.text.trim(),
          "unit": _selectedUnit,
          "role": _selectedRole,
          "email": _emailController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı başarıyla eklendi!')),
        );
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${error['detail'] ?? 'Bilinmeyen hata'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İstek hatası: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text(
          'Yeni Kullanıcı Ekle',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_nameController, 'Ad Soyad', (value) {
                  if (value == null || value.isEmpty) return 'Lütfen isim girin';
                  return null;
                }),
                const SizedBox(height: 16),
                _buildTextField(_usernameController, 'Kullanıcı Adı', (value) {
                  if (value == null || value.isEmpty) return 'Lütfen kullanıcı adı girin';
                  return null;
                }),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'E-posta', (value) {
                  if (value == null || value.isEmpty) return 'Lütfen e-posta girin';
                  if (!_validateEmail(value)) return 'Geçerli bir e-posta adresi girin';
                  return null;
                }),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Şifre', (value) {
                  if (value == null || value.isEmpty) return 'Lütfen şifre girin';
                  if (!_validatePassword(value)) {
                    return 'Şifre en az 8 karakter olmalı, büyük/küçük harf ve sayı içermeli';
                  }
                  return null;
                }, obscure: true),
                const SizedBox(height: 16),
                _buildDropdown(units, _selectedUnit, 'Birim', (value) {
                  setState(() => _selectedUnit = value!);
                }),
                const SizedBox(height: 16),
                _buildDropdown(['User', 'Admin'], _selectedRole, 'Yetki', (value) {
                  setState(() => _selectedRole = value!);
                }),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _addUser,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Kullanıcıyı Kaydet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String? Function(String?) validator, {bool obscure = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      obscureText: obscure,
      validator: validator,
    );
  }

  Widget _buildDropdown(List<String> items, String value, String label, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}
