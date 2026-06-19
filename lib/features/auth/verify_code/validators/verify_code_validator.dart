// Si el usuario escribe mas de 4 digitos, se detiene.
// cuadno se completa los 4 digitos se puede validar OTP
List<String> validateAndFormatOtp(String value, int maxLength) {
  if (value.length > maxLength) return [];
  return List.generate(maxLength, (i) => i < value.length ? value[i] : '');
}
