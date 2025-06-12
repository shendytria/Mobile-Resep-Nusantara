import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uts1/services/auth_service.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  static const Color darkGreen = Color(0xFF074132);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();

  // Ubah struktur untuk menyimpan quantity dan unit
  List<Map<String, String>> _ingredients = [
    {'name': '', 'quantity': '', 'unit': ''},
  ];
  List<String> _instructions = [''];

  // Untuk Flutter Web dan Mobile
  File? _pickedImageFile;
  Uint8List? _webImage;
  XFile? _pickedXFile;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;

  bool _isLoading = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // URL yang tepat bergantung pada lingkungan pengembangan
      final baseUrl =
          kIsWeb
              ? 'http://127.0.0.1:8000' // Untuk web development
              : 'http://10.0.2.2:8000'; // Untuk emulator Android

      final response = await http.get(
        Uri.parse('$baseUrl/api/recipecategories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data['data'] ?? []);
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first['category_id'].toString();
          }
          _isLoadingCategories = false;
        });
      } else {
        throw Exception(
          'Failed to load categories (status ${response.statusCode})',
        );
      }
    } catch (e) {
      print('ERROR FETCHING CATEGORIES: $e');
      setState(() => _isLoadingCategories = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching categories: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _pickedXFile = pickedFile;

      if (kIsWeb) {
        // Untuk Flutter Web, baca gambar sebagai bytes
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
        });
      } else {
        // Untuk aplikasi mobile
        setState(() {
          _pickedImageFile = File(pickedFile.path);
        });
      }
    }
  }

  // Modifikasi fungsi untuk bahan dengan quantity dan unit
  void _addIngredient() => setState(
    () => _ingredients.add({'name': '', 'quantity': '', 'unit': ''}),
  );
  void _removeIngredient(int index) {
    if (_ingredients.length > 1) {
      setState(() => _ingredients.removeAt(index));
    }
  }

  void _addInstruction() => setState(() => _instructions.add(''));
  void _removeInstruction(int index) {
    if (_instructions.length > 1) {
      setState(() => _instructions.removeAt(index));
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final ingredients =
        _ingredients.where((i) => i['name']!.trim().isNotEmpty).toList();
    final instructions =
        _instructions.where((i) => i.trim().isNotEmpty).toList();

    if (ingredients.isEmpty || instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bahan dan langkah tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken(); // Gunakan AuthService
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login ulang.');
      }
      print('Token dari AuthService: $token'); // Debug token

      final baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
      final uri = Uri.parse('$baseUrl/api/recipes');
      final request = http.MultipartRequest('POST', uri);

      // Tambahkan header
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Tambahkan fields
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['preparation_time'] = _prepTimeController.text.trim();
      request.fields['cooking_time'] = _cookTimeController.text.trim();
      request.fields['servings'] = _servingsController.text.trim();
      request.fields['category_id'] = _selectedCategory ?? '';

      for (int i = 0; i < ingredients.length; i++) {
        request.fields['ingredients[$i][name]'] = ingredients[i]['name'] ?? '';
        request.fields['ingredients[$i][quantity]'] =
            ingredients[i]['quantity'] ?? '';
        request.fields['ingredients[$i][unit]'] = ingredients[i]['unit'] ?? '';
      }

      for (int i = 0; i < instructions.length; i++) {
        request.fields['steps[$i][step_number]'] = '${i + 1}';
        request.fields['steps[$i][description]'] = instructions[i];
      }

      if (_pickedXFile != null) {
        String? mimeType = 'image/jpeg';
        if (_pickedXFile!.name.contains('.')) {
          String extension = _pickedXFile!.name.split('.').last.toLowerCase();
          switch (extension) {
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'png':
              mimeType = 'image/png';
              break;
            case 'gif':
              mimeType = 'image/gif';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
            case 'bmp':
              mimeType = 'image/bmp';
              break;
            case 'heic':
              mimeType = 'image/heic';
              break;
          }
        }

        if (kIsWeb && _webImage != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'thumbnail_photo',
              _webImage!,
              filename: _pickedXFile!.name,
              contentType: MediaType(
                mimeType.split('/')[0],
                mimeType.split('/')[1],
              ),
            ),
          );
        } else if (_pickedImageFile != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'thumbnail_photo',
              _pickedImageFile!.path,
              contentType: MediaType(
                mimeType.split('/')[0],
                mimeType.split('/')[1],
              ),
            ),
          );
        }
      }

      print('Data fields yang dikirim: ${request.fields}'); // Debug fields
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop(true); // Kembalikan true untuk refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep berhasil disimpan')),
        );
      } else {
        throw Exception(
          'Gagal menyimpan resep (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('SUBMISSION ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(label: 'Tutup', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Custom Input Decoration
  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: darkGreen.withOpacity(0.7)) : null,
      labelStyle: TextStyle(color: darkGreen.withOpacity(0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // Custom Card Widget
  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
        title: const Text(
          'Tambah Resep',
          style: TextStyle(
            color: darkGreen, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: darkGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Information Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Dasar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkGreen,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _titleController,
                            decoration: _buildInputDecoration('Judul Resep', icon: Icons.title),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: _buildInputDecoration('Deskripsi', icon: Icons.description),
                            maxLines: 3,
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          _isLoadingCategories
                              ? const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: darkGreen),
                                )
                              : _categories.isEmpty
                                  ? const Text(
                                      'Tidak ada kategori tersedia',
                                      style: TextStyle(color: Colors.red),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      items: _categories
                                          .map(
                                            (category) => DropdownMenuItem(
                                              value: category['category_id'].toString(),
                                              child: Text(category['name']),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) => setState(() => _selectedCategory = value),
                                      decoration: _buildInputDecoration('Kategori', icon: Icons.category),
                                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                                    ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Time and Servings Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Masakan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkGreen,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _prepTimeController,
                                  decoration: _buildInputDecoration('Persiapan (menit)', icon: Icons.access_time_rounded),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || int.tryParse(v) == null ? 'Angka valid' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _cookTimeController,
                                  decoration: _buildInputDecoration('Memasak (menit)', icon: Icons.whatshot_rounded),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || int.tryParse(v) == null ? 'Angka valid' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _servingsController,
                            decoration: _buildInputDecoration('Jumlah Porsi', icon: Icons.people_rounded),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || int.tryParse(v) == null ? 'Angka valid' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Foto Resep',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkGreen,
                            ),
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              ),
                              child: _pickedXFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? _webImage != null
                                              ? Image.memory(_webImage!, fit: BoxFit.cover, width: double.infinity)
                                              : const Center(child: Text('Gambar dipilih'))
                                          : _pickedImageFile != null
                                              ? Image.file(_pickedImageFile!, fit: BoxFit.cover, width: double.infinity)
                                              : const Center(child: Text('Gambar dipilih')),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, size: 48, color: darkGreen),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap untuk pilih gambar',
                                          style: TextStyle(
                                            color: darkGreen,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ingredients Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bahan-Bahan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkGreen,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addIngredient,
                                icon: const Icon(Icons.add, color: darkGreen),
                                label: const Text('Tambah', style: TextStyle(color: darkGreen)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._ingredients.asMap().entries.map((entry) {
                            final index = entry.key;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: entry.value['name'],
                                          onChanged: (val) => _ingredients[index]['name'] = val,
                                          decoration: InputDecoration(
                                            labelText: 'Nama Bahan',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _removeIngredient(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          initialValue: entry.value['quantity'],
                                          onChanged: (val) => _ingredients[index]['quantity'] = val,
                                          decoration: InputDecoration(
                                            labelText: 'Jumlah',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          initialValue: entry.value['unit'],
                                          onChanged: (val) => _ingredients[index]['unit'] = val,
                                          decoration: InputDecoration(
                                            labelText: 'Satuan',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Instructions Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Langkah-Langkah',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkGreen,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addInstruction,
                                icon: const Icon(Icons.add, color: darkGreen),
                                label: const Text('Tambah', style: TextStyle(color: darkGreen)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._instructions.asMap().entries.map((entry) {
                            final index = entry.key;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: darkGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: entry.value,
                                      onChanged: (val) => _instructions[index] = val,
                                      decoration: InputDecoration(
                                        labelText: 'Langkah ${index + 1}',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeInstruction(index),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Resep',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}