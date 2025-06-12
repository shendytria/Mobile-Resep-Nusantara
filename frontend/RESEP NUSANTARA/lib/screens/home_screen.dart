import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/recipe_model.dart';
import '../providers/recipe_provider.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color darkGreen = const Color(0xFF0D5C46);

  List<Recipe> filteredRecipes = [];
  String selectedCategory = 'Semua';
  List<String> categories = ['Semua'];

  final TextEditingController _searchController = TextEditingController();

  int _selectedIndex = 0;
  bool _isLoadingCategories = true;
  String? _categoryError;
  bool _isLoadingRecipes = true;
  String? profilePictureUrl;
  XFile? _pickedImage;

  String? _token;

  Timer? _debounceTimer;

  final String baseUrl =
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Listener input search dengan debounce agar tidak panggil filter terlalu sering
    _searchController.addListener(_onSearchChanged);

    // Load token dari AuthService, lalu load data jika token valid
    _initAuthAndData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce input search selama 300ms
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _filterRecipes();
    });
  }

  Future<void> _initAuthAndData() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      // Token tidak ditemukan, langsung pindah ke login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _token = token;
    });

    // Setelah set token, load kategori dan resep
    await Future.wait([_fetchCategories(), _loadRecipes()]);
  }

  Future<void> _fetchCategories() async {
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
              if (_token != null) 'Authorization': 'Bearer $_token',
            },
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
        _categoryError = 'Gagal memuat kategori: $e';
        _isLoadingCategories = false;
      });
      print('Error fetching categories: $e');
    }
  }

  Future<void> _loadRecipes() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecipes = true;
    });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    try {
      await recipeProvider.loadRecipes(token: _token ?? '');
      _filterRecipes(); // langsung filter setelah load
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat resep: $e')));
      }
      print('Error loading recipes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecipes = false;
        });
      }
    }
  }

  void _filterRecipes() {
    if (!mounted) return;

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final recipes = recipeProvider.allRecipes;

    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredRecipes =
          recipes.where((recipe) {
            final matchesCategory =
                selectedCategory == 'Semua' ||
                recipe.category == selectedCategory;
            final matchesSearch = recipe.title.toLowerCase().contains(query);
            return matchesCategory && matchesSearch;
          }).toList();
    });
  }

  void _selectCategory(String category) {
    if (mounted) {
      setState(() {
        selectedCategory = category;
      });
      _filterRecipes();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.pushNamed(
          context,
          '/cart',
          arguments: {'username': widget.username},
        );
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
      default:
        // index 0 is Home, do nothing
        break;
    }
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
              // Header dengan greeting dan profile avatar
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
                        "Mau masak apa hari ini?",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/edit-profile',
                        arguments: {'username': widget.username},
                      );
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      child:
                          _pickedImage != null && !kIsWeb
                              ? ClipOval(
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder:
                                      (context, error, stackTrace) => Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                                ),
                              )
                              : CachedNetworkImage(
                                imageUrl:
                                    profilePictureUrl ??
                                    'images/default_profile.jpg',
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) =>
                                        const CircularProgressIndicator(),
                                errorWidget:
                                    (context, url, error) => Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[600],
                                    ),
                                imageBuilder:
                                    (context, imageProvider) => Container(
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

              // Search field
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
                    hintText: 'Cari resep...',
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

              // Recipe Grid/List
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (ctx, recipeProvider, _) {
                    if (_isLoadingRecipes) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (filteredRecipes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: darkGreen.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada resep yang tersedia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadRecipes,
                      child: GridView.builder(
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
                          final recipe = filteredRecipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/recipe-detail',
                                arguments: recipe,
                              ).then((_) => _filterRecipes());
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // Floating button to add new recipe
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final result = await Navigator.pushNamed(context, '/add-recipe');
            if (result == true && mounted) {
              await _loadRecipes();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resep berhasil ditambahkan!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal menambahkan resep: $e')),
              );
            }
          }
        },
        backgroundColor: darkGreen,
        child: const Icon(Icons.add, color: Colors.white),
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
