import 'package:cloud_firestore/cloud_firestore.dart';

class Empresa {
  final String? email;
  final String? nombreEmpresa;
  final String? telefono;
  final String? representante;
  final String? logoUrl;
  final int? saldo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? estado;

  Empresa({
    this.email,
    this.nombreEmpresa,
    this.telefono,
    this.representante,
    this.logoUrl,
    this.saldo,
    this.createdAt,
    this.updatedAt,
    this.estado,
  });

  factory Empresa.fromMap(Map<String, dynamic> map) {
    return Empresa(
      email: map['email'] as String?,
      nombreEmpresa: map['nombreEmpresa'] as String?,
      telefono: map['telefono'] as String?,
      representante: map['representante'] as String?,
      logoUrl: map['logoUrl'] as String?,
      saldo: map['saldo'] is int ? map['saldo'] as int : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      estado: map['estado'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nombreEmpresa': nombreEmpresa,
      'telefono': telefono,
      'representante': representante,
      'logoUrl': logoUrl,
      'saldo': saldo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'estado': estado,
    };
  }
}
