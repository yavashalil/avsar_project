import 'dart:convert';
import 'package:flutter/material.dart';
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
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late String _role;
  late String _unit;

  final List<String> _roles = ['User', 'Admin'];
  final List<String> _units = [
    'Muhasebe',
    'Pazarlama',
    'İK',
    'Satın Alma',
    'Finans',
    'Bilgi İşlem'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _usernameController = TextEditingController(text: widget.user['username']);
    _passwordController = TextEditingController();
    _role = widget.user['role'] ?? 'User';
    _unit = _units.contains(widget.user['unit'])
        ? widget.user['unit']
        : _units.first;
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await http.put(
          Uri.parse('${widget.baseUrl}/users/${widget.user['username']}'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'username': _usernameController.text,
            'name': _nameController.text,
            'unit': _unit,
            'role': _role,
            'password': _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
          }),
        );

        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          print(
              "⚠️ Güncelleme başarısız: ${response.statusCode} - ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Kullanıcı güncellenemedi! Hata: ${response.body}")),
          );
        }
      } catch (e) {
        print("⚠️ Kullanıcı güncellerken hata oluştu: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Beklenmeyen bir hata oluştu!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kullanıcı Düzenle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Ad boş olamaz'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Kullanıcı adı boş olamaz'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Şifre (Değiştirmek için girin)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _role,
                        items: _roles
                            .map((role) => DropdownMenuItem(
                                value: role, child: Text(role)))
                            .toList(),
                        onChanged: (value) => setState(() => _role = value!),
                        decoration: InputDecoration(
                          labelText: 'Yetki',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _unit,
                        items: _units
                            .map((unit) => DropdownMenuItem(
                                value: unit, child: Text(unit)))
                            .toList(),
                        onChanged: (value) => setState(() => _unit = value!),
                        decoration: InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _updateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child:
                  const Text('Güncelle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
