import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/recipe_model.dart';
import '../services/auth_service.dart';

class EditRecipeScreen extends StatefulWidget {
  const EditRecipeScreen({super.key});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  static const Color darkGreen = Color(0xFF074132);

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;
  late TextEditingController _servingsController;

  List<Map<String, String>> _ingredients = [];
  List<String> _instructions = [];
  File? _pickedImageFile;
  Uint8List? _webImage;
  XFile? _pickedXFile;
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  String? _errorMessage;
  Recipe? _recipe;
  String? _token;

  final String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _prepTimeController = TextEditingController();
    _cookTimeController = TextEditingController();
    _servingsController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    final token = await AuthService.getToken();
    print('EditRecipeScreen: Token retrieved: $token');

    if (token == null || token.isEmpty) {
      print('EditRecipeScreen: No token found, redirecting to login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi kadaluarsa. Silakan login ulang.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _token = token;
    });

    await _initializeRecipe();
    await _fetchCategories();
  }

  Future<void> _initializeRecipe() async {
    final recipe = ModalRoute.of(context)?.settings.arguments as Recipe?;
    if (recipe == null) {
      setState(() {
        _errorMessage = 'Resep tidak ditemukan';
      });
      return;
    }
    setState(() {
      _recipe = recipe;
      _titleController.text = recipe.title;
      _descriptionController.text = recipe.description;
      _prepTimeController.text = recipe.prepTimeMinutes.toString();
      _cookTimeController.text = recipe.cookTimeMinutes.toString();
      _servingsController.text = recipe.servings.toString();
      _ingredients = recipe.ingredients.map((ingredient) {
        if (ingredient is String) {
          final parts = ingredient.split(' ');
          String quantity = parts.isNotEmpty ? parts[0] : '';
          String unit = parts.length > 1 ? parts[1] : '';
          String name = parts.length > 2 ? parts.sublist(2).join(' ') : '';
          return {'name': name, 'quantity': quantity, 'unit': unit};
        } else if (ingredient is IngredientModel) {
          return {
            'name': ingredient.name?.toString() ?? '',
            'quantity': ingredient.quantity?.toString() ?? '',
            'unit': ingredient.unit?.toString() ?? '',
          };
        }
        return {'name': '', 'quantity': '', 'unit': ''};
      }).toList();
      _instructions = List.from(recipe.steps.map((step) {
        return step is String ? step : (step.description?.toString() ?? '');
      }));
    });
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipecategories'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('EditRecipeScreen: Categories response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data['data'] ?? []);
          if (_recipe != null && _categories.isNotEmpty) {
            final matchingCategory = _categories.firstWhere(
              (category) => category['name'] == _recipe!.category,
              orElse: () => _categories.first,
            );
            _selectedCategory = matchingCategory['category_id'].toString();
          }
          _isLoadingCategories = false;
        });
      } else if (response.statusCode == 401) {
        print('EditRecipeScreen: Unauthorized (categories), redirecting to login');
        await AuthService.clearAuthData();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        throw Exception('Gagal memuat kategori: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('EditRecipeScreen: Error fetching categories: $e');
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = 'Gagal memuat kategori: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
        if (kIsWeb) {
          _pickImageWeb(pickedFile);
        } else {
          _pickedImageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _pickImageWeb(XFile pickedFile) async {
    final bytes = await pickedFile.readAsBytes();
    setState(() => _webImage = bytes);
  }

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

    final ingredients = _ingredients.where((i) => i['name']!.trim().isNotEmpty).toList();
    final instructions = _instructions.where((i) => i.trim().isNotEmpty).toList();

    if (ingredients.isEmpty || instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bahan dan langkah tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await AuthService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }

      final recipe = _recipe!;
      if (_pickedXFile == null && _pickedImageFile == null && _webImage == null) {
        final response = await http.put(
          Uri.parse('$baseUrl/api/recipes/${recipe.id}'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'preparation_time': _prepTimeController.text.trim(),
            'cooking_time': _cookTimeController.text.trim(),
            'servings': _servingsController.text.trim(),
            'category_id': _selectedCategory ?? '',
            'user_id': userId,
            'ingredients': ingredients
                .map((i) => {
                      'name': i['name'],
                      'quantity': i['quantity'],
                      'unit': i['unit'],
                    })
                .toList(),
            'steps': instructions
                .asMap()
                .entries
                .map((entry) => {
                      'step_number': (entry.key + 1).toString(),
                      'description': entry.value,
                    })
                .toList(),
          }),
        );

        print('EditRecipeScreen: Update recipe response (JSON): ${response.statusCode} - ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (!mounted) return;
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resep berhasil diperbarui')),
          );
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            'Failed to update recipe: ${response.statusCode} - ${errorData['message'] ?? response.body}',
          );
        }
      } else {
        final request = http.MultipartRequest(
          'PUT',
          Uri.parse('$baseUrl/api/recipes/${recipe.id}'),
        );

        request.headers['Authorization'] = 'Bearer $_token';
        request.headers['Accept'] = 'application/json';

        request.fields['title'] = _titleController.text.trim();
        request.fields['description'] = _descriptionController.text.trim();
        request.fields['preparation_time'] = _prepTimeController.text.trim();
        request.fields['cooking_time'] = _cookTimeController.text.trim();
        request.fields['servings'] = _servingsController.text.trim();
        request.fields['category_id'] = _selectedCategory ?? '';
        request.fields['user_id'] = userId;
        request.fields['ingredients'] = jsonEncode(
          ingredients
              .map((i) => {
                    'name': i['name'],
                    'quantity': i['quantity'],
                    'unit': i['unit'],
                  })
              .toList(),
        );
        request.fields['steps'] = jsonEncode(
          instructions
              .asMap()
              .entries
              .map((entry) => {
                    'step_number': (entry.key + 1).toString(),
                    'description': entry.value,
                  })
              .toList(),
        );

        if (_pickedXFile != null) {
          String mimeType = 'image/jpeg';
          String extension = _pickedXFile!.name.split('.').last.toLowerCase();
          if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'gif') {
            mimeType = 'image/gif';
          } else if (extension == 'webp') {
            mimeType = 'image/webp';
          } else if (extension == 'bmp') {
            mimeType = 'image/bmp';
          } else if (extension == 'heic') {
            mimeType = 'image/heic';
          }

          if (kIsWeb && _webImage != null) {
            request.files.add(
              http.MultipartFile.fromBytes(
                'thumbnail_photo',
                _webImage!,
                filename: _pickedXFile!.name,
                contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
              ),
            );
          } else if (_pickedImageFile != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'thumbnail_photo',
                _pickedImageFile!.path,
                contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
              ),
            );
          }
        }

        print('EditRecipeScreen: Sending request to update recipe: ${request.fields}');
        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);

        print('EditRecipeScreen: Update recipe response (Multipart): ${response.statusCode} - ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (!mounted) return;
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resep berhasil diperbarui')),
          );
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            'Failed to update recipe: ${response.statusCode} - ${errorData['message'] ?? response.body}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      print('EditRecipeScreen: Error updating recipe: $e');
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
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: darkGreen),
          title: const Text(
            'Edit Resep',
            style: TextStyle(
              color: darkGreen,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
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
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Kembali',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
        title: const Text(
          'Edit Resep',
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
                                              child: Text(category['name'] ?? 'Tanpa Nama'),
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
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Wajib diisi';
                                    final value = int.tryParse(v);
                                    return value == null || value <= 0 ? 'Masukkan angka positif' : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _cookTimeController,
                                  decoration: _buildInputDecoration('Memasak (menit)', icon: Icons.whatshot_rounded),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Wajib diisi';
                                    final value = int.tryParse(v);
                                    return value == null || value <= 0 ? 'Masukkan angka positif' : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _servingsController,
                            decoration: _buildInputDecoration('Jumlah Porsi', icon: Icons.people_rounded),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Wajib diisi';
                              final value = int.tryParse(v);
                              return value == null || value <= 0 ? 'Masukkan angka positif' : null;
                            },
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
                                  : _recipe != null && _recipe!.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            _recipe!.imageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline, size: 48, color: darkGreen),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Gagal memuat gambar',
                                                  style: TextStyle(
                                                    color: darkGreen,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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
                                          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
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
                                          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
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
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
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
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.0,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Menyimpan...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Simpan Perubahan',
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