import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uts1/services/auth_service.dart';
import 'dart:convert';
import 'dart:io';
import '../providers/cart_provider.dart';
import '../widgets/ingredient_card.dart';
import '../models/ingredient_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class CartScreen extends StatefulWidget {
  final String username;
  const CartScreen({super.key, required this.username});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Color darkGreen = const Color(0xFF0D5C46);

  List<Ingredient> filteredIngredients = [];
  String selectedCategory = 'Semua';
  List<String> categories = ['Semua']; // Inisialisasi dengan 'All'
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 1;
  bool _isLoadingCategories = true;
  String? _categoryError;
  String? profilePictureUrl;

  // Base URL untuk API
  final String baseUrl =
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _filterIngredients();
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIngredients();
      _fetchCategories(); // Ambil kategori dari API
      _fetchProfilePicture(); // Ambil gambar profil dari API
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/ingredientcategories'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> categoryList = data['data'] ?? [];
        setState(() {
          categories = [
            'Semua',
            ...categoryList.map((cat) => cat['name'] as String).toList(),
          ];
          _isLoadingCategories = false;
        });
      } else {
        throw Exception('Gagal memuat kategori: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _categoryError = 'Error: $e';
        _isLoadingCategories = false;
      });
      print('Error fetching categories: $e');
    }
  }

  void _loadIngredients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ingredients/full'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawIngredients = data['data'];

        final List<Ingredient> loadedIngredients =
            rawIngredients.map((json) => Ingredient.fromJson(json)).toList();

        // Simpan ke Provider
        Provider.of<CartProvider>(
          context,
          listen: false,
        ).setIngredients(loadedIngredients);

        _filterIngredients();
      } else {
        print('Gagal memuat data bahan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading ingredients: $e');
    }
  }

  void _filterIngredients() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final ingredients = cartProvider.ingredients;

    setState(() {
      filteredIngredients =
          ingredients.where((ingredient) {
            final matchesCategory =
                selectedCategory == 'Semua' ||
                ingredient.category == selectedCategory;
            final matchesSearch = ingredient.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );
            return matchesCategory && matchesSearch;
          }).toList();
    });
  }

  void _selectCategory(String category) {
    setState(() {
      selectedCategory = category;
      _filterIngredients();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/',
          arguments: {'username': widget.username},
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushNamed(
          context,
          '/favorites',
          arguments: {'username': widget.username},
        );
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/profile',
          arguments: {'username': widget.username},
        );
        break;
    }
  }

  Future<void> _fetchProfilePicture() async {
    try {
      final token = await _getAuthToken(); // Asumsi ada fungsi untuk mengambil token
      if (token == null) {
        setState(() {
          profilePictureUrl = 'images/default_profile.jpg';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data']['user'];
          setState(() {
            profilePictureUrl = userData['profile_picture'] ?? 'images/default_profile.jpg';
          });
        } else {
          setState(() {
            profilePictureUrl = 'images/default_profile.jpg';
          });
        }
      } else {
        setState(() {
          profilePictureUrl = 'images/default_profile.jpg';
        });
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
      setState(() {
        profilePictureUrl = 'images/default_profile.jpg';
      });
    }
  }

  Future<String?> _getAuthToken() async {
    // Asumsi ini diambil dari AuthService atau penyimpanan lokal
    // Sesuaikan dengan implementasi AuthService kamu
    return await AuthService.getToken(); // Ganti dengan logika autentikasi yang sesuai
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo, ${widget.username}!",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Butuh bahan masakan apa?",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      print(
                        'Profile picture tapped, navigating to EditProfilePage',
                      );
                      Navigator.pushNamed(
                        context,
                        '/edit-profile',
                        arguments: {'username': widget.username},
                      );
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      child: CachedNetworkImage(
                        imageUrl: profilePictureUrl ?? 'images/default_profile.jpg',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari bahan...',
                    prefixIcon: Icon(Icons.search, color: darkGreen),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Categories horizontal list
              if (_isLoadingCategories)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_categoryError != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _categoryError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            _selectCategory(category);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? darkGreen
                                      : darkGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected ? darkGreen : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : darkGreen,
                                fontSize: 14,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              Expanded(
                child: Consumer<CartProvider>(
                  builder: (ctx, cartProvider, _) {
                    return filteredIngredients.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: darkGreen.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Tidak ada bahan yang ditemukan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: filteredIngredients.length,
                          itemBuilder: (context, index) {
                            return IngredientCard(
                              ingredient: filteredIngredients[index],
                            );
                          },
                        );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.home_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.home, color: darkGreen),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.search_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.search, color: darkGreen),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.favorite_outline),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.favorite, color: darkGreen),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.person_outline),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: darkGreen),
                ),
                label: '',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: darkGreen,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}