import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uts1/models/recipe_model.dart';
import 'package:uts1/screens/profile/collection_detail_page.dart';

class CollectionItem {
  final String id;
  final String title;
  final String imageUrl;
  final int itemCount;
  final String? createdAt;

  CollectionItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.itemCount,
    this.createdAt,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    String? thumbnail = '';
    List<dynamic> recipes = json['recipes'] ?? [];

    if (recipes.isNotEmpty) {
      thumbnail = recipes.last['thumbnail_photo'];
    }

    return CollectionItem(
      id: json['collection_id'].toString(),
      title: json['name'],
      imageUrl:
          thumbnail != null && thumbnail.isNotEmpty
              ? 'http://127.0.0.1:8000/storage/$thumbnail'
              : 'images/default.jpg',
      itemCount: json['recipes_count'] ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class CollectionsPage extends StatefulWidget {
  final Recipe? recipe;
  final String? token;

  const CollectionsPage({super.key, this.recipe, this.token});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final Color darkGreen = const Color(0xFF0D5C46);
  List<CollectionItem> collections = [];
  bool isLoading = false;
  String? errorMessage;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchCollections();
  }

  Future<void> _loadTokenAndFetchCollections() async {
    if (widget.token != null) {
      setState(() {
        token = widget.token;
      });
      fetchCollections();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken == null) {
      setState(() {
        errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    setState(() {
      token = savedToken;
    });

    fetchCollections();
  }

  Future<void> fetchCollections() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/collections'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            collections =
                (data['data'] as List)
                    .map((item) => CollectionItem.fromJson(item))
                    .toList();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = data['message'] ?? 'Gagal memuat koleksi';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Gagal memuat koleksi: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _addRecipeToCollection(
    String collectionId,
    String collectionName,
  ) async {
    if (widget.recipe == null) return;

    print(
      'Attempting to add recipe ${widget.recipe!.id} to collection $collectionId',
    );

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/toggle-collection'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipe_id': widget.recipe!.id,
          'collection_id': collectionId,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (mounted) {
            Navigator.pop(context, {
              'collectionId': collectionId,
              'collectionName': collectionName,
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] ?? 'Gagal menambahkan resep ke koleksi',
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menambahkan resep: ${response.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      }
    }
  }

  Future<void> _createNewCollection() async {
    String newCollectionName = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          titlePadding: const EdgeInsets.only(top: 16),
          title: Column(
            children: [
              Icon(Icons.bookmark_add_outlined, size: 40, color: darkGreen),
              const SizedBox(height: 12),
              Text(
                'Koleksi Baru',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: darkGreen,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Nama Koleksi',
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: darkGreen, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  newCollectionName = value;
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCollectionName.isNotEmpty) {
                  try {
                    final response = await http.post(
                      Uri.parse('http://127.0.0.1:8000/api/collections'),
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({'name': newCollectionName}),
                    );

                    Navigator.pop(context); // Tutup dialog apapun hasilnya

                    if (response.statusCode == 201) {
                      final data = jsonDecode(response.body);
                      final newCollection = CollectionItem.fromJson(
                        data['data'],
                      );
                      setState(() {
                        collections.add(newCollection);
                      });

                      if (widget.recipe != null) {
                        await _addRecipeToCollection(
                          newCollection.id,
                          newCollection.title,
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              data['message'] ?? 'Koleksi berhasil dibuat',
                            ),
                          ),
                        );
                      }
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal membuat koleksi: ${response.statusCode}',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Terjadi kesalahan: $e')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipe != null ? "Pilih Koleksi" : "Koleksi Saya",
          style: const TextStyle(color: Color(0xFF0D5C46)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : collections.isEmpty
                ? const Center(child: Text('Belum ada koleksi'))
                : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap:
                          widget.recipe != null
                              ? () => _addRecipeToCollection(
                                collections[index].id,
                                collections[index].title,
                              )
                              : () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CollectionDetailPage(
                                          collectionId: collections[index].id,
                                          collectionName:
                                              collections[index].title,
                                        ),
                                  ),
                                );
                                // Tangani hasil dari CollectionDetailPage
                                if (result != null &&
                                    result is Map<String, dynamic>) {
                                  if (result['deleted'] == true) {
                                    setState(() {
                                      collections.removeAt(index);
                                    });
                                  } else if (result['updatedName'] != null) {
                                    setState(() {
                                      collections[index] = CollectionItem(
                                        id: collections[index].id,
                                        title: result['updatedName'],
                                        imageUrl: collections[index].imageUrl,
                                        itemCount: result['itemCount'],
                                      );
                                    });
                                  }
                                }
                              },
                      child: CollectionCard(collection: collections[index]),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: darkGreen,
        onPressed: _createNewCollection,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  final CollectionItem collection;

  const CollectionCard({super.key, required this.collection});
  String _formatDate(String? isoDate) {
    if (isoDate == null) return "Unknown";
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return "Invalid date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child:
                collection.imageUrl.startsWith('http')
                    ? Image.network(
                      collection.imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'images/default.jpg',
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                    : Image.asset(
                      collection.imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 50),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${collection.itemCount} items',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  'Dibuat: ${_formatDate(collection.createdAt)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
