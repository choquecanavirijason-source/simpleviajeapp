/// Modifica la lista de dígitos OTP según la tecla presionada.
/// Retorna true si la lista fue modificada (para llamar a setState).
bool modificarCodigoOtp(List<String> codeDigits, String key) {
  if (key == 'Borrar') {
    // Borra el último dígito ingresado
    for (int i = codeDigits.length - 1; i >= 0; i--) {
      if (codeDigits[i] != '') {
        codeDigits[i] = '';
        return true;
      }
    }
    return false;
  } else if (key == 'OK') {
    // Validar solo si todos los dígitos están completos
    if (codeDigits.every((digit) => digit != '')) {
      final code = codeDigits.join();
      print('Código OTP ingresado: $code');
      // Aquí puedes validar el código OTP
    }
    return false;
  } else {
    // Añadir número si hay espacio
    for (int i = 0; i < codeDigits.length; i++) {
      if (codeDigits[i] == '') {
        codeDigits[i] = key;
        return true;
      }
    }
    return false;
  }
}

/// Modifica el número telefónico según la tecla presionada.
/// Retorna el nuevo número modificado.
String modificarNumeroTelefonico(String phoneNumber, String key) {
  if (key == 'Borrar') {
    if (phoneNumber.isNotEmpty) {
      return phoneNumber.substring(0, phoneNumber.length - 1);
    }
    return phoneNumber;
  } else if (key == 'OK') {
    print('Número telefónico ingresado: $phoneNumber');
    return phoneNumber;
  } else {
    return phoneNumber + key;
  }
}
