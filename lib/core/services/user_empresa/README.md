# Carpeta: `user_empresa`

Capa de negocio para **leer el campo `empresa`** dentro de `users/<uid>` y entregarlo a la UI **sin usar Firebase en la UI**.

---

## ¿Qué hace?
- Obtiene el **Campo** `empresa` que vive en `users/<uid>.empresa`.
- Trae **todos los campos internos** de `empresa`:  
  `email`, `telefono`, `nombreEmpresa`, etc.

## ¿De dónde sale el `uid`?
- **Del módulo `cuenta_user`** (servicio de cuenta).  
- La UI debe importar esto para poder pedir el `uid` y poder acceder al campo `empresa`:
  ```dart
  import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

 - Si no importas ese cuenta_user.dart en el UI no podras obtener el campo Empresa.

 -----

 Qué NO hace

La UI no debe importar Firebase ni adapters (cloud_firestore, firebase_*, firebase_adapters.dart).

Esta carpeta solo lee users/<uid>.empresa. No crea ni actualiza (a menos que agregues métodos para eso).