extension StringCasingExtension on String {
  String toTitleCase() {
    // 1. Divide la cadena por espacios.
    return split(' ')
        // 2. Mapea cada palabra.
        .map((word) {
          if (word.isEmpty) {
            return '';
          }
          // 3. Devuelve la primera letra en mayúscula y el resto en minúscula.
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        // 4. Une las palabras de nuevo con espacios.
        .join(' ');
  }
}
