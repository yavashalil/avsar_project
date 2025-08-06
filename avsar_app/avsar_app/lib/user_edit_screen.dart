import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String baseUrl;

  const UserEditScreen({super.key, required this.user, required this.baseUrl});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _emailController;
  late String _role;
  late String _unit;

  final List<String> _units = [
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
    _nameController = TextEditingController(text: widget.user['name']);
    _usernameController = TextEditingController(text: widget.user['username']);
    _passwordController = TextEditingController();
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _role = widget.user['role'] ?? 'User';
    _unit = _units.contains(widget.user['unit']) ? widget.user['unit'] : _units.first;
  }

  bool _validateEmail(String email) {
    return RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.isEmpty || // Boş ise opsiyonel alan
        (password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password));
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Oturum token bulunamadı");

      final response = await http.put(
        Uri.parse('${widget.baseUrl}/users/${widget.user['username']}'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'name': _nameController.text.trim(),
          'unit': _unit,
          'role': _role,
          'email': _emailController.text.trim(),
          'password': _passwordController.text.isNotEmpty
              ? _passwordController.text.trim()
              : null,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${error['detail'] ?? 'Kullanıcı güncellenemedi'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Beklenmeyen bir hata oluştu: $e")),
      );
    }
  }

  Future<void> _deleteUser() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Oturum token bulunamadı");

      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/users/${widget.user['username']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kullanıcı başarıyla silindi!")),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${error['detail'] ?? 'Kullanıcı silinemedi'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Beklenmeyen bir hata oluştu: $e")),
      );
    }
  }

  Future<void> _confirmDeleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcıyı Sil'),
          content: const Text('Bu kullanıcıyı silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('İptal')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Düzenle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Ad Soyad'),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen isim girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Kullanıcı Adı'),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen kullanıcı adı girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDecoration('E-Posta'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Lütfen e-posta giriniz';
                    if (!_validateEmail(value)) return 'Geçerli bir e-posta giriniz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: _inputDecoration('Yeni Şifre (isteğe bağlı)'),
                  obscureText: true,
                  validator: (value) {
                    if (!_validatePassword(value ?? '')) {
                      return 'Şifre en az 8 karakter, büyük/küçük harf ve sayı içermeli';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: _inputDecoration('Birim Seçiniz'),
                  items: _units.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (value) => setState(() => _unit = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _inputDecoration('Yetki'),
                  items: ['User', 'Admin']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) => setState(() => _role = value!),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _updateUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Güncelle', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _confirmDeleteUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Kullanıcıyı Sil', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
