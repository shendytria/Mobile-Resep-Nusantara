import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/ingredient_model.dart';
import '../screens/ingredient_detail_page.dart';

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;
  final Color darkGreen = const Color(0xFF0D5C46);

  const IngredientCard({super.key, required this.ingredient, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Construct the full image URL with logic to avoid double URLs
    final String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
    final String imageUrl = ingredient.imageUrl != null && ingredient.imageUrl.isNotEmpty
        ? (ingredient.imageUrl.startsWith('http')
            ? ingredient.imageUrl // Use the full URL if it already starts with http
            : '$baseUrl/images/ingredients/${ingredient.imageUrl}?${DateTime.now().millisecondsSinceEpoch}') // Append cache-buster
        : '';

    // Debug logs
    print('kIsWeb: $kIsWeb, Base URL: $baseUrl');
    print('Image URL in IngredientCard: $imageUrl');

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IngredientDetailPage(ingredientId: ingredient.id),
              ),
            );
          },
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
                          headers: const {'Accept': 'image/*'},
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ?? 1)
                                    : null,
                                color: darkGreen,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image in IngredientCard: $error, URL: $imageUrl');
                            return Image.asset(
                              'images/default.jpg', // Fallback image
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading fallback image: $error');
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
                          'images/default.jpg', // Fallback image
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading default image: $error');
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${ingredient.price.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                          ingredient.category,
                          style: TextStyle(fontSize: 10, color: darkGreen),
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