// lib/models/cart_item.dart

class CartItem {
  String item;
  double price;
  String? category; // 'Market', 'Store', or null

  CartItem({
    required this.item,
    required this.price,
    this.category,
  });

  bool get isTask => price == 0.0;

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'price': price,
      'category': category,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      item: json['item'],
      price: (json['price'] as num).toDouble(),
      category: json['category'],
    );
  }
}