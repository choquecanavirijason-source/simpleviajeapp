empresa_cache.dart:
lee/escribe/borra caché (maneja DateTime/Timestamp y subset de campos).
One-liners:
await EmpresaCache.save(uid, e, fields: {'email','telefono'});
final eLocal = await EmpresaCache.read(uid);
await EmpresaCache.clear(uid);