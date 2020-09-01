class AdaptyProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final String localizedPrice;
  final String currency;

  AdaptyProduct(this.id, this.title, this.description, this.price,
      this.localizedPrice, this.currency);

  AdaptyProduct.fromJson(Map<String, dynamic> json)
      : id = json[_AdaptyProductKeys._id] as String,
        title = json[_AdaptyProductKeys._title] as String,
        description = json[_AdaptyProductKeys._description] as String,
        price = json[_AdaptyProductKeys._price] as String,
        localizedPrice = json[_AdaptyProductKeys._localizedPrice] as String,
        currency = json[_AdaptyProductKeys._currency] as String;

  @override
  String toString() {
    return '${_AdaptyProductKeys._id}: $id, '
        '${_AdaptyProductKeys._title}: $title, '
        '${_AdaptyProductKeys._description}: $description, '
        '${_AdaptyProductKeys._price}: $price, '
        '${_AdaptyProductKeys._localizedPrice}: $localizedPrice, '
        '${_AdaptyProductKeys._currency}: $currency';
  }
}

class _AdaptyProductKeys {
  static const _id = "id";
  static const _title = "title";
  static const _description = "description";
  static const _price = "price";
  static const _localizedPrice = "localizedPrice";
  static const _currency = "currency";
}
