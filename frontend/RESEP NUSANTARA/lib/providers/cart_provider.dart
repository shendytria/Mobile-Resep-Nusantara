import 'package:flutter/material.dart';
import '../models/ingredient_model.dart';

class CartProvider with ChangeNotifier {
  List<Ingredient> _ingredients = [];

  List<Ingredient> get ingredients => _ingredients;

  void setIngredients(List<Ingredient> newIngredients) {
    _ingredients = newIngredients;
    notifyListeners();
  }

  void addIngredient(Ingredient ingredient) {
    _ingredients.add(ingredient);
    notifyListeners();
  }

  void removeIngredient(Ingredient ingredient) {
    _ingredients.remove(ingredient);
    notifyListeners();
  }

  void clearCart() {
    _ingredients.clear();
    notifyListeners();
  }

  double get totalPrice {
    return _ingredients.fold(0.0, (total, item) => total + item.price);
  }
}
