  class Recipe {
    final int id;
    final String title;
    final String description;
    final String imageUrl;
    final int prepTimeMinutes;
    final int cookTimeMinutes;
    final int servings;
    final List<IngredientModel> ingredients;
    final List<StepModel> steps;
    final String category;
    late final bool isFavorite;
    late final bool isInCollection;

    Recipe({
      required this.id,
      required this.title,
      required this.description,
      required this.imageUrl,
      required this.prepTimeMinutes,
      required this.cookTimeMinutes,
      required this.servings,
      required this.ingredients,
      required this.steps,
      required this.category,
      this.isFavorite = false,
      this.isInCollection = false,
    });

    factory Recipe.fromJson(Map<String, dynamic> json) {
      return Recipe(
        id: json['recipe_id'] ?? json['id'] ?? 0,
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        imageUrl: json['thumbnail_photo'] ?? json['imageUrl'] ?? '',
        prepTimeMinutes: json['preparation_time'] ?? json['prepTimeMinutes'] ?? 0,
        cookTimeMinutes: json['cooking_time'] ?? json['cookTimeMinutes'] ?? 0,
        servings: json['servings'] ?? 1,
        ingredients:
            (json['ingredients'] as List<dynamic>?)
                ?.map((e) => IngredientModel.fromJson(e))
                .toList() ??
            [],
        steps:
            (json['steps'] as List<dynamic>?)
                ?.map((e) => StepModel.fromJson(e))
                .toList() ??
            [],
        category:
            json['category'] != null && json['category'] is Map
                ? json['category']['name'] ?? 'Unknown'
                : json['category']?.toString() ?? 'Unknown',
        isFavorite: json['is_favorited'] ?? false,
        isInCollection: json['isInCollection'] ?? false,
      );
    }

  get thumbnailPhoto => null;

    Map<String, dynamic> toJson() {
      return {
        'id': id,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        'servings': servings,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'category': category,
        'isFavorite': isFavorite,
        'isInCollection': isInCollection,
      };
    }

    Recipe copyWith({
      int? id,
      String? title,
      String? description,
      String? imageUrl,
      int? prepTimeMinutes,
      int? cookTimeMinutes,
      int? servings,
      List<IngredientModel>? ingredients,
      List<StepModel>? steps,
      String? category,
      bool? isFavorite,
      bool? isInCollection,
    }) {
      return Recipe(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
        cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
        servings: servings ?? this.servings,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        category: category ?? this.category,
        isFavorite: isFavorite ?? this.isFavorite,
        isInCollection: isInCollection ?? this.isInCollection,
      );
    }
  }

  class IngredientModel {
    final String name;
    final String quantity;
    final String unit;

    IngredientModel({
      required this.name,
      required this.quantity,
      required this.unit,
    });

    factory IngredientModel.fromJson(Map<String, dynamic> json) {
      return IngredientModel(
        name: json['name'] ?? '',
        quantity: json['quantity']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
      );
    }
    Map<String, dynamic> toJson() {
      return {'name': name, 'quantity': quantity, 'unit': unit};
    }

    split(String s) {}
  }

  class StepModel {
    final int step_id; // Tambahkan step_id
    final int recipe_id; // Tambahkan recipe_id
    final int step_number;
    final String description;

    StepModel({
      required this.step_id,
      required this.recipe_id,
      required this.step_number,
      required this.description,
    });

    factory StepModel.fromJson(Map<String, dynamic> json) {
      return StepModel(
        step_id: json['step_id'] ?? 0, // Petakan step_id
        recipe_id: json['recipe_id'] ?? 0, // Petakan recipe_id
        step_number: json['step_number'] ?? 0,
        description: json['description'] ?? '',
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'step_id': step_id,
        'recipe_id': recipe_id,
        'step_number': step_number,
        'description': description,
      };
    }
  }
