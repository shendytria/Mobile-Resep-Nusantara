import 'package:flutter/material.dart';
import '../models/recipe_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final Color darkGreen = const Color(0xFF0D5C46);

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Base URL for your Laravel server
    final String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
    final String imageUrl = recipe.imageUrl != null && recipe.imageUrl.isNotEmpty
        ? recipe.imageUrl.startsWith('http')
            ? recipe.imageUrl
            : '$baseUrl/storage/${recipe.imageUrl}'
        : '';

    // Debug log
    print('RecipeCard: Image URL: $imageUrl, kIsWeb: $kIsWeb');

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('RecipeCard: Error loading network image: $error, URL: $imageUrl');
                            return Image.asset(
                              'images/default.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('RecipeCard: Error loading default asset: $error');
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : Image.asset(
                          'images/default.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('RecipeCard: Error loading default asset: $error');
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    children: [
                      if (recipe.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      if (recipe.isInCollection)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.bookmark,
                            color: Colors.yellow,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: darkGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          recipe.category,
                          style: TextStyle(fontSize: 10, color: darkGreen),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.people, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        '${recipe.servings}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}