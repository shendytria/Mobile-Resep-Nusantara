import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recipe_model.dart';
import '../data/recipe_data.dart';

class RecipeRepository {
  static const String _favoritesKey = 'favorite_recipes';
  static const String _collectionsKey = 'collection_recipes'; // New key for collections

  // Mendapatkan semua resep
  Future<List<Recipe>> getAllRecipes() async {
    // Dalam aplikasi nyata, ini mungkin mengambil data dari API
    return RecipeData.sampleRecipes;
  }

  // Mendapatkan resep berdasarkan kategori
  Future<List<Recipe>> getRecipesByCategory(String category) async {
    final recipes = await getAllRecipes();
    if (category == 'All') {
      return recipes;
    }
    return recipes.where((recipe) => recipe.category == category).toList();
  }

  // Mendapatkan resep berdasarkan kata kunci pencarian
  Future<List<Recipe>> searchRecipes(String query) async {
    final recipes = await getAllRecipes();
    return recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(query.toLowerCase()) ||
          recipe.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Menyimpan resep favorit ke penyimpanan lokal
  Future<void> saveFavoriteRecipes(List<Recipe> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesIds =
    favorites.map((recipe) => recipe.id.toString()).toList();
    await prefs.setStringList(_favoritesKey, favoritesIds);
  }

  // Mendapatkan resep favorit dari penyimpanan lokal
  Future<List<Recipe>> getFavoriteRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? favoritesIds = prefs.getStringList(_favoritesKey);
    if (favoritesIds == null || favoritesIds.isEmpty) {
      return [];
    }

    final recipes = await getAllRecipes();
    return recipes.where((recipe) {
      return favoritesIds.contains(recipe.id.toString());
    }).map((recipe) => recipe.copyWith(isFavorite: true)).toList();
  }

  // Menambahkan resep ke favorit
  Future<void> addToFavorites(Recipe recipe) async {
    final favorites = await getFavoriteRecipes();
    if (!favorites.any((r) => r.id == recipe.id)) {
      favorites.add(recipe.copyWith(isFavorite: true));
      await saveFavoriteRecipes(favorites);
    }
  }

  // Menghapus resep dari favorit
  Future<void> removeFromFavorites(Recipe recipe) async {
    final favorites = await getFavoriteRecipes();
    favorites.removeWhere((r) => r.id == recipe.id);
    await saveFavoriteRecipes(favorites);
  }

  // Memeriksa apakah resep adalah favorit
  Future<bool> isFavorite(int recipeId) async {
    final favorites = await getFavoriteRecipes();
    return favorites.any((r) => r.id == recipeId);
  }

  // ---- COLLECTION METHODS ----

  // Menyimpan resep koleksi ke penyimpanan lokal
  Future<void> saveCollectionRecipes(List<Recipe> collection) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> collectionIds =
        collection.map((recipe) => recipe.id.toString()).toList();
    await prefs.setStringList(_collectionsKey, collectionIds);
  }

  // Mendapatkan resep koleksi dari penyimpanan lokal
  Future<List<Recipe>> getCollectionRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? collectionIds = prefs.getStringList(_collectionsKey);
    if (collectionIds == null || collectionIds.isEmpty) {
      return [];
    }

    final recipes = await getAllRecipes();
    return recipes.where((recipe) {
      return collectionIds.contains(recipe.id.toString());
    }).map((recipe) => recipe.copyWith(isInCollection: true)).toList();
  }

  // Menambahkan resep ke koleksi
  Future<void> addToCollection(Recipe recipe) async {
    final collection = await getCollectionRecipes();
    if (!collection.any((r) => r.id == recipe.id)) {
      collection.add(recipe.copyWith(isInCollection: true));
      await saveCollectionRecipes(collection);
    }
  }

  // Menghapus resep dari koleksi
  Future<void> removeFromCollection(Recipe recipe) async {
    final collection = await getCollectionRecipes();
    collection.removeWhere((r) => r.id == recipe.id);
    await saveCollectionRecipes(collection);
  }

  // Memeriksa apakah resep ada dalam koleksi
  Future<bool> isInCollection(int recipeId) async {
    final collection = await getCollectionRecipes();
    return collection.any((r) => r.id == recipeId);
  }
}