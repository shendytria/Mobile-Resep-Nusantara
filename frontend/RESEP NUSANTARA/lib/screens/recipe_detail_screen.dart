import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../providers/recipe_provider.dart';
import '../services/auth_service.dart';
import 'package:uts1/screens/profile/collections_page.dart';
import 'package:uts1/screens/profile/collection_detail_page.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with TickerProviderStateMixin {
  late Recipe currentRecipe;
  late bool isFavorite;
  late bool isInCollection;
  bool isLoading = true;
  String? _token;

  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeScreen();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final token = await AuthService.getToken();
    print('RecipeDetailScreen: Token retrieved: $token');

    if (token == null || token.isEmpty) {
      print('RecipeDetailScreen: No token found, redirecting to login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil token. Silakan login ulang.'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _token = token;
    });

    await _loadRecipeDetails(token);
  }

  Future<void> _loadRecipeDetails(String token) async {
    final recipe = ModalRoute.of(context)!.settings.arguments as Recipe;
    print('RecipeDetailScreen: Recipe received: ${recipe.id}, ${recipe.title}');
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    setState(() {
      isLoading = true;
    });

    try {
      await recipeProvider.loadRecipeDetails(recipe.id, token: token);
      final index = recipeProvider.allRecipes.indexWhere(
        (r) => r.id == recipe.id,
      );
      currentRecipe = index != -1 ? recipeProvider.allRecipes[index] : recipe;
      isFavorite = currentRecipe.isFavorite;
      isInCollection = currentRecipe.isInCollection;
      
      // Start animations
      _animationController.forward();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _fabAnimationController.forward();
      });
    } catch (e) {
      print('RecipeDetailScreen: Error loading recipe details: $e');
      if (e.toString().contains('401')) {
        await AuthService.clearAuthData();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        currentRecipe = recipe;
        isFavorite = recipe.isFavorite;
        isInCollection = recipe.isInCollection;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat detail resep: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _toggleFavorite() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.toggleFavorite(currentRecipe, token: _token!);

    setState(() {
      isFavorite = !isFavorite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isFavorite ? Colors.red.shade600 : Colors.grey.shade700,
      ),
    );
  }

  void _toggleCollection() async {
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan. Silakan login ulang.'),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionsPage(recipe: currentRecipe, token: _token),
      ),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      try {
        print('Loading updated recipe details for ID: ${currentRecipe.id}');
        final updatedRecipe = await recipeProvider.loadRecipeDetails(
          currentRecipe.id,
          token: _token!,
        );
        print('Updated isInCollection from API: ${updatedRecipe.isInCollection}');
        setState(() {
          currentRecipe = updatedRecipe;
          isInCollection = updatedRecipe.isInCollection;
          print('isInCollection set to: $isInCollection');
        });
      } catch (e) {
        print('Error updating collection status: $e');
        setState(() {
          isInCollection = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Resep ditambahkan ke koleksi'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.yellow.shade700,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionDetailPage(
            collectionId: result['collectionId'],
            collectionName: result['collectionName'],
          ),
        ),
      );
    }
  }

  void _editRecipe() async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-recipe',
      arguments: currentRecipe,
    );
    if (result == true && _token != null && mounted) {
      await _loadRecipeDetails(_token!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Resep berhasil diperbarui'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _deleteRecipe() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
              const SizedBox(width: 12),
              const Text('Hapus Resep'),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus resep "${currentRecipe.title}"? Tindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
                try {
                  await recipeProvider.deleteRecipe(currentRecipe.id, token: _token!);
                  if (mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Resep berhasil dihapus'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.red.shade600,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus resep: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Opsi Resep',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildBottomSheetItem(
                  icon: Icons.edit_rounded,
                  title: 'Edit Resep',
                  onTap: () {
                    Navigator.pop(context);
                    _editRecipe();
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.delete_rounded,
                  title: 'Hapus Resep',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteRecipe();
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.share_rounded,
                  title: 'Berbagi Resep',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Berbagi resep'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color ?? Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Memuat detail resep...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String baseUrl = 'http://127.0.0.1:8000';
    final String imageUrl = currentRecipe.imageUrl.isNotEmpty
        ? currentRecipe.imageUrl.startsWith('http')
            ? currentRecipe.imageUrl
            : '$baseUrl/storage/${currentRecipe.imageUrl}'
        : 'images/default.jpg';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentRecipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'images/default.jpg',
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    isInCollection ? Icons.bookmark : Icons.bookmark_border,
                    color: isInCollection ? Colors.yellow : Colors.white,
                  ),
                  onPressed: _toggleCollection,
                  tooltip: 'Simpan ke koleksi',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: 'Favorit',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: _showMoreOptions,
                  tooltip: 'Opsi lainnya',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                currentRecipe.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Info Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoCard(
                                    context,
                                    Icons.access_time_rounded,
                                    'Prep Time',
                                    '${currentRecipe.prepTimeMinutes} min',
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoCard(
                                    context,
                                    Icons.whatshot_rounded,
                                    'Cook Time',
                                    '${currentRecipe.cookTimeMinutes} min',
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoCard(
                                    context,
                                    Icons.people_rounded,
                                    'Servings',
                                    '${currentRecipe.servings}',
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Ingredients Section
                            _buildSectionHeader('Bahan-bahan', Icons.list_alt_rounded),
                            const SizedBox(height: 16),
                            _buildIngredientsSection(),
                            const SizedBox(height: 32),

                            // Steps Section
                            _buildSectionHeader('Langkah-langkah', Icons.format_list_numbered_rounded),
                            const SizedBox(height: 16),
                            _buildStepsSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "edit",
                  onPressed: _editRecipe,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: "delete",
                  onPressed: _deleteRecipe,
                  backgroundColor: Colors.red.shade600,
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    if (currentRecipe.ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              'Belum ada bahan yang ditambahkan',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: currentRecipe.ingredients.asMap().entries.map((entry) {
          int index = entry.key;
          var ingredient = entry.value;
          bool isLast = index == currentRecipe.ingredients.length - 1;
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: isLast ? null : Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepsSection() {
    if (currentRecipe.steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              'Belum ada langkah yang ditambahkan',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: currentRecipe.steps.map((step) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${step.step_number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}