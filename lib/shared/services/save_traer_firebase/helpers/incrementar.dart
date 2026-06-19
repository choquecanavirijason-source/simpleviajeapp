import 'package:cloud_firestore/cloud_firestore.dart';

class Incrementar {
  final num value;
  const Incrementar(this.value);
}

Incrementar incrementar(num value) => Incrementar(value);
Incrementar decrementar(num value) => Incrementar(-value);

Map<String, dynamic> transformarIncrementables(Map<String, dynamic> input) {
  dynamic _translate(dynamic value) {
    if (value is Incrementar) {
      return FieldValue.increment(value.value.toDouble());
    } else if (value is Map) {
      return (value as Map).map(
        (k, v) => MapEntry(k.toString(), _translate(v)),
      );
    } else if (value is List) {
      return value.map(_translate).toList();
    }
    return value;
  }

  return input.map((k, v) => MapEntry(k.toString(), _translate(v)));
}
