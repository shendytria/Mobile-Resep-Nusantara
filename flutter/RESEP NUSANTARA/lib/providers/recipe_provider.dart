import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../services/recipe_service.dart';

class RecipeProvider extends ChangeNotifier {
  final RecipeService _recipeService = RecipeService();

  List<Recipe> _allRecipe = []; // Inisialisasi sebagai list kosong
  List<Recipe> _favoriteRecipes = [];
  List<Recipe> _collectionRecipes = [];
  bool _isLoading = false;

  List<Recipe> get allRecipes => _allRecipe;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  List<Recipe> get collectionRecipes => _collectionRecipes;
  List<Recipe> get recipes => _allRecipe;
  bool get isLoading => _isLoading;

  RecipeProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    final token = await _getToken();
    if (token != null) {
      await loadRecipes(token: token);
      await loadFavorites(token: token); // Muat favorit saat inisialisasi
      await loadCollections(token: token); // Muat koleksi saat inisialisasi
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Retrieved token: $token');
    return token;
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    print('Retrieved user_id: $userId');
    return userId;
  }

  Future<void> loadRecipes({required String token}) async {
    _setLoading(true);
    final userId = await _getUserId();
    if (userId == null) {
      print('User ID not found, skipping recipe load');
      _setLoading(false);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/recipes?user_id=$userId');
    print('Mengirim permintaan ke: $url dengan token: $token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('Status kode: ${response.statusCode}');
      print('Respons body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> recipeList = data['data'] ?? [];
        _allRecipe = recipeList.map((json) => Recipe.fromJson(json)).toList();
      } else {
        print('Failed to load recipes: ${response.statusCode}');
        _allRecipe = []; // Reset ke list kosong jika gagal
      }
    } catch (e) {
      print('Error fetching recipes: $e');
      _allRecipe = [];
    } finally {
      notifyListeners();
      _setLoading(false);
    }
  }

  Future<void> loadFavorites({required String token}) async {
    _setLoading(true);
    final userId = await _getUserId();
    if (userId == null) {
      print('User ID not found, skipping favorites load');
      _setLoading(false);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/favorites?user_id=$userId');
    print('Mengirim permintaan ke: $url dengan token: $token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Status kode: ${response.statusCode}');
      print('Respons body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> favoriteList = data['data'] ?? [];
        _favoriteRecipes = favoriteList.map((json) => Recipe.fromJson(json)).toList();
      } else {
        print('Failed to load favorites: ${response.statusCode}');
        _favoriteRecipes = [];
      }
    } catch (e) {
      print('Error fetching favorites: $e');
      _favoriteRecipes = [];
    } finally {
      notifyListeners();
      _setLoading(false);
    }
  }

  Future<void> loadCollections({required String token}) async {
    _setLoading(true);
    final userId = await _getUserId();
    if (userId == null) {
      print('User ID not found, skipping collections load');
      _setLoading(false);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/collections?user_id=$userId');
    print('Mengirim permintaan ke: $url dengan token: $token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Status kode: ${response.statusCode}');
      print('Respons body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> collectionList = data['data'] ?? [];
        _collectionRecipes = collectionList.map((json) => Recipe.fromJson(json)).toList();
      } else {
        print('Failed to load collections: ${response.statusCode}');
        _collectionRecipes = [];
      }
    } catch (e) {
      print('Error fetching collections: $e');
      _collectionRecipes = [];
    } finally {
      notifyListeners();
      _setLoading(false);
    }
  }

  Future<void> toggleFavorite(Recipe recipe, {required String token}) async {
    _setLoading(true);
    final url = Uri.parse('http://127.0.0.1:8000/api/recipes/${recipe.id}/favorite');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final index = _allRecipe.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _allRecipe[index] = _allRecipe[index].copyWith(isFavorite: !_allRecipe[index].isFavorite);
        }

        // Sinkronisasi daftar favorit setelah toggle
        await loadFavorites(token: token);

        notifyListeners();
      } else {
        throw Exception('Failed to toggle favorite: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error toggling favorite: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleCollection(Recipe recipe, {required String token}) async {
    _setLoading(true);
    final url = Uri.parse('http://127.0.0.1:8000/api/collections/${recipe.id}/recipes');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final index = _allRecipe.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _allRecipe[index] = _allRecipe[index].copyWith(isInCollection: !_allRecipe[index].isInCollection);
        }

        // Sinkronisasi daftar koleksi setelah toggle
        await loadCollections(token: token);

        notifyListeners();
      } else {
        throw Exception('Failed to toggle collection: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error toggling collection: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteRecipe(int id, {required String token}) async {
    _setLoading(true);
    final url = Uri.parse('http://127.0.0.1:8000/api/recipes/$id');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _allRecipe.removeWhere((r) => r.id == id);
        await loadFavorites(token: token);
        await loadCollections(token: token);
        notifyListeners();
      } else {
        throw Exception('Failed to delete recipe: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting recipe: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveRecipe(Recipe recipe, {required String token}) async {
    try {
      await _recipeService.saveUserRecipe(recipe, token: token);
      await loadRecipes(token: token);
    } catch (e) {
      print('Error saving recipe: $e');
      throw Exception('Gagal menyimpan resep: $e');
    }
  }

  Future<int> getNewRecipeId() async {
    return await _recipeService.generateNewRecipeId();
  }

  Future<Recipe> loadRecipeDetails(int id, {required String token}) async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User ID tidak ditemukan');
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/recipes/$id?user_id=$userId');
    print('Mengirim permintaan ke: $url dengan token: $token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Status kode: ${response.statusCode}');
      print('Respons body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Respons API: $data');
        if (data['success'] != true || data['data'] == null) {
          throw Exception('Respons API tidak valid');
        }
        final recipeData = data['data'];
        final updatedRecipe = Recipe.fromJson(recipeData);
        final index = _allRecipe.indexWhere((r) => r.id == id);
        if (index != -1) {
          _allRecipe[index] = updatedRecipe;
        } else {
          _allRecipe.add(updatedRecipe);
        }
        notifyListeners();
        return updatedRecipe;
      } else {
        throw Exception('Failed to load recipe details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching recipe details: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}