class Ingredient {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final String? description; // deskripsi bisa null
  final List<SupermarketInfo>? supermarkets; // daftar supermarket, bisa null

  Ingredient({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.description,
    this.supermarkets,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
      imageUrl: json['imageUrl'],
      category: json['category'],
      description: json['description'], // nullable
      supermarkets: json['supermarkets'] != null
          ? (json['supermarkets'] as List)
          .map((e) => SupermarketInfo.fromJson(e))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'description': description,
      'supermarkets': supermarkets?.map((e) => e.toJson()).toList(),
    };
  }

  static List<Ingredient> listFromJson(List<dynamic> list) {
    return list.map((item) => Ingredient.fromJson(item)).toList();
  }
}

class SupermarketInfo {
  final String name;
  final String address;
  final String? openHours;
  final double? latitude;   // optional, kalau data ada
  final double? longitude;  // optional, kalau data ada
  final bool? isAvailable;  // optional, kalau data ada
  final String? lastUpdated; // optional, kalau data ada

  SupermarketInfo({
    required this.name,
    required this.address,
    this.openHours,
    this.latitude,
    this.longitude,
    this.isAvailable,
    this.lastUpdated,
  });

  factory SupermarketInfo.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    return SupermarketInfo(
      name: json['name'],
      address: json['address'],
      openHours: json['open_hours'],
      latitude: location != null
          ? double.tryParse(location['latitude'].toString())
          : null,
      longitude: location != null
          ? double.tryParse(location['longitude'].toString())
          : null,
      isAvailable: _toBool(json['isAvailable'] ?? json['is_available']),
      lastUpdated: json['lastUpdated'] ?? json['last_updated'],
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'open_hours': openHours,
      'latitude': latitude,
      'longitude': longitude,
      'is_available': isAvailable,
      'last_updated': lastUpdated,
    };
  }
}
bool? _toBool(dynamic val) {
  if (val == null) return null;
  if (val is bool) return val;
  if (val is int) return val == 1;
  if (val is String) {
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return null;
}
