import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/recipe_model.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class FavoriteScreen extends StatefulWidget {
  final String username;
  const FavoriteScreen({super.key, required this.username});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final Color darkGreen = const Color(0xFF0D5C46);
  List<Recipe> favoriteRecipes = [];
  List<Recipe> filteredRecipes = []; // Untuk menyimpan hasil filter pencarian
  List<String> categories = ['Semua'];
  String selectedCategory = 'Semua';
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  String? _categoryError;
  String? _token;
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 2;
  String? profilePictureUrl;

  // Gunakan baseUrl yang sesuai untuk web atau emulator
  final String baseUrl =
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeScreen();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredRecipes =
          favoriteRecipes
              .where(
                (recipe) => recipe.title.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ),
              )
              .toList();
    });
    print('FavoriteScreen: Filtered recipes: ${filteredRecipes.length}');
  }

  Future<void> _initializeScreen() async {
    // Ambil token menggunakan AuthService
    final token = await AuthService.getToken();
    print('FavoriteScreen: Token retrieved: $token');

    if (token == null || token.isEmpty) {
      print('FavoriteScreen: No token found, redirecting to login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi kadaluarsa. Silakan login ulang.'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _token = token;
    });

    // Load kategori, resep favorit, dan data pengguna secara paralel
    await Future.wait([_loadCategories(), _loadFavoriteRecipes(), _fetchUserData()]);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/recipecategories'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print(
        'FavoriteScreen: Categories response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> categoryList = jsonData['data'] ?? [];
        setState(() {
          categories = [
            'Semua',
            ...categoryList.map((e) => e['name'].toString()),
          ];
          _isLoadingCategories = false;
        });
        print('FavoriteScreen: Loaded categories: $categories');
      } else if (response.statusCode == 401) {
        print(
          'FavoriteScreen: Unauthorized (categories), redirecting to login',
        );
        await AuthService.clearAuthData();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        throw Exception(
          'Gagal memuat kategori: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('FavoriteScreen: Error fetching categories: $e');
      setState(() {
        _categoryError = 'Gagal memuat kategori: $e';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadFavoriteRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/favorites'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print(
        'FavoriteScreen: Favorites response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> favoriteList = jsonData['data'] ?? [];
        setState(() {
          favoriteRecipes =
              favoriteList.map((json) => Recipe.fromJson(json)).toList();
          filteredRecipes = favoriteRecipes; // Inisialisasi filteredRecipes
          _isLoading = false;
        });
        print(
          'FavoriteScreen: Loaded favorite recipes: ${favoriteRecipes.length}',
        );
      } else if (response.statusCode == 401) {
        print('FavoriteScreen: Unauthorized (favorites), redirecting to login');
        await AuthService.clearAuthData();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else if (response.statusCode == 404) {
        print('FavoriteScreen: Endpoint /api/favorites not found');
        setState(() {
          favoriteRecipes = [];
          filteredRecipes = [];
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endpoint favorit tidak ditemukan di server.'),
            ),
          );
        }
      } else {
        throw Exception(
          'Gagal memuat resep favorit: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('FavoriteScreen: Error fetching favorite recipes: $e');
      setState(() {
        favoriteRecipes = [];
        filteredRecipes = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat resep favorit: $e')),
        );
      }
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
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
          throw Exception('Failed to load user data: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load user data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('FavoriteScreen: Error fetching user data: $e');
      setState(() {
        profilePictureUrl = 'images/default_profile.jpg';
      });
    }
  }

  void _selectCategory(String category) {
    setState(() {
      selectedCategory = category;
      if (category == 'Semua') {
        filteredRecipes = favoriteRecipes; // Reset filter ke semua resep
      } else {
        filteredRecipes =
            favoriteRecipes
                .where((recipe) => recipe.category == category)
                .toList();
      }
    });
    print('FavoriteScreen: Selected category: $category');
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
        Navigator.pushNamed(
          context,
          '/cart',
          arguments: {'username': widget.username},
        );
        break;
      case 2:
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${widget.username}!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${filteredRecipes.length} Resep Tersimpan',
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
                                'FavoriteScreen: Profile picture tapped, navigating to EditProfilePage',
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
                      // Search Bar
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
                            hintText: 'Cari resep favorit...',
                            prefixIcon: Icon(Icons.search, color: darkGreen),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
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
                                            isSelected
                                                ? darkGreen
                                                : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : darkGreen,
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
                      // Recipes Grid / Empty
                      Expanded(
                        child:
                            filteredRecipes.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.favorite_border,
                                        size: 64,
                                        color: darkGreen.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Tidak ada resep favorit',
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
                                  itemCount: filteredRecipes.length,
                                  itemBuilder: (context, index) {
                                    return RecipeCard(
                                      recipe: filteredRecipes[index],
                                      onTap: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          '/recipe-detail',
                                          arguments: filteredRecipes[index],
                                        );
                                        _loadFavoriteRecipes(); // Refresh setelah kembali
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