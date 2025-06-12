import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/recipe_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeService {
  // Base URL for the API
  final String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  // Cache keys
  static const String _favoritesKey = 'favorites';
  static const String _collectionsKey = 'collections';

  // Get all recipes from the API
  Future<List<Recipe>> getAllRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug print untuk melihat struktur data yang diterima
        print('API Response Structure: ${data.keys}');

        if (data['success'] == true && data['data'] != null) {
          if (data['data'] is List) {
            final List<dynamic> recipeList = data['data'];
            return recipeList.map((json) => Recipe.fromJson(json)).toList();
          } else {
            throw Exception('Data recipes bukan dalam format list');
          }
        } else {
          throw Exception('Format respons tidak sesuai');
        }
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error detail: $e');
      throw Exception('Error fetching recipes: $e');
    }
  }

  // Get a specific recipe by ID
  Future<Recipe> getRecipeById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipes/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Recipe.fromJson(data['data']);
      } else {
        throw Exception('Failed to load recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching recipe details: $e');
    }
  }

  // Get favorite recipes (currently using local storage)
  Future<List<Recipe>> getFavoriteRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoritesKey) ?? [];

    if (favoriteIds.isEmpty) {
      return [];
    }

    try {
      // This is a simple implementation.
      // In a real app, you might want to fetch these from the API
      final allRecipes = await getAllRecipes();
      return allRecipes
          .where((recipe) => favoriteIds.contains(recipe.id.toString()))
          .toList();
    } catch (e) {
      throw Exception('Error fetching favorite recipes: $e');
    }
  }

  // Get collection recipes (currently using local storage)
  Future<List<Recipe>> getCollectionRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionIds = prefs.getStringList(_collectionsKey) ?? [];

    if (collectionIds.isEmpty) {
      return [];
    }

    try {
      // This is a simple implementation.
      // In a real app, you might want to fetch these from the API
      final allRecipes = await getAllRecipes();
      return allRecipes
          .where((recipe) => collectionIds.contains(recipe.id.toString()))
          .toList();
    } catch (e) {
      throw Exception('Error fetching collection recipes: $e');
    }
  }

  // Check if a recipe is in favorites
  Future<bool> isFavorite(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoritesKey) ?? [];
    return favoriteIds.contains(recipeId.toString());
  }

  // Check if a recipe is in collection
  Future<bool> isInCollection(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final collectionIds = prefs.getStringList(_collectionsKey) ?? [];
    return collectionIds.contains(recipeId.toString());
  }

  // Toggle favorite status
  Future<void> toggleFavorite(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoritesKey) ?? [];

    if (favoriteIds.contains(recipeId.toString())) {
      favoriteIds.remove(recipeId.toString());
    } else {
      favoriteIds.add(recipeId.toString());
    }

    await prefs.setStringList(_favoritesKey, favoriteIds);
  }

  // Toggle collection status
  Future<void> toggleCollection(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final collectionIds = prefs.getStringList(_collectionsKey) ?? [];

    if (collectionIds.contains(recipeId.toString())) {
      collectionIds.remove(recipeId.toString());
    } else {
      collectionIds.add(recipeId.toString());
    }

    await prefs.setStringList(_collectionsKey, collectionIds);
  }

  // Save a user recipe
  Future<void> saveUserRecipe(Recipe recipe, {required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recipe.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 201) {
        throw Exception('Failed to save recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error saving recipe: $e');
    }
  }

  // Delete a user recipe
  Future<void> deleteUserRecipe(int recipeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/recipes/$recipeId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting recipe: $e');
    }
  }

  // Generate a new recipe ID
  // In a real API this would typically be handled by the backend
  Future<int> generateNewRecipeId() async {
    try {
      final recipes = await getAllRecipes();
      if (recipes.isEmpty) {
        return 1;
      }
      return recipes.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}