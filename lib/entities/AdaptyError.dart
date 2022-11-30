//
//  AdaptyError.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
part '../entities.json/AdaptyErrorJSONBuilder.dart';

@immutable
class AdaptyError {
  const AdaptyError();

  @override
  String toString() => 'AdaptyError()';
}
