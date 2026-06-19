// lib/core/services/user_empresa/estado.dart

/// SOLO lo que viene de la nube: users/<uid>.empresa.estado
/// Acepta "pendiente" o "aprobado" (y también "aprovado" por si hay typo).
enum RemotoEmpresaEstado { pendiente, aprobado }

/// Normaliza y parsea cualquier valor remoto al enum.
RemotoEmpresaEstado parseRemotoEstado(dynamic valor) {
  final s = _norm(valor);
  if (s == 'aprobado' || s == 'aprovado') return RemotoEmpresaEstado.aprobado;
  return RemotoEmpresaEstado.pendiente; // fallback seguro
}

String _norm(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  const from = 'áéíóúàèìòùäëïöüâêîôû';
  const to = 'aeiouaeiouaeiouaeiou';
  var out = s;
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
