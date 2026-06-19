import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'dart:convert';

import 'package:buses2/shared/widgets/modal_inferior/detalles_usuario.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_servicio.dart';
import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
// 👇 importa tu scaffold con botón fijo
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import './modal_editar_saldo.dart';

import '../data/taxistas_registrados_data.dart';
import '../data/empresa_data.dart';

class DetallesTaxistaPage {
  static Future<void> show(
    BuildContext context, {
    required TaxistaRegistrado taxista,
  }) async {
    // Trae empresa + trabajador usando el uid del taxista
    final data = await traerEmpresaYTrabajador(uidTaxista: taxista.id);

    final headerEstado = data?.trabajador.estadoTaxista ?? "pendiente";

    DetallesUsuarioBottomSheet.show(
      context,
      nombre: taxista.nombre ?? "Sin nombre",
      telefono: taxista.telefono ?? "—",
      correo: taxista.correo ?? "—",
      estado: headerEstado,
      puntuacion: 4.7,
      headerColors: const [
        Colors.green,
        Color.fromARGB(255, 143, 184, 144),
      ], // cambiar a color entero
      servicios: const [
        EtiquetaServicio(
          icono: Icons.local_taxi,
          texto: "Taxi",
          color: Colors.yellow,
        ),
      ],
      opcionesEstado: const ['Pendiente', 'Aprobado', 'Suspendido'],
      onConfirmar: (nuevoEstado) async {
        await ActualizarEstadoTaxista.actualizar(
          uidTaxista: taxista.id,
          nuevoEstado: nuevoEstado,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado a "$nuevoEstado"'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      },
      // 👇 Aquí le pasamos el objeto entero
      child: _DetallesContent(taxista: taxista),
    );
  }
}

class _DetallesContent extends StatefulWidget {
  final TaxistaRegistrado taxista;
  const _DetallesContent({required this.taxista, super.key});

  @override
  State<_DetallesContent> createState() => _DetallesContentState();
}

class _DetallesContentState extends State<_DetallesContent> {
  Empresa? _empresa;
  TrabajadorEmpresa? _trabajador;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEmpresa();
  }

  Future<void> _cargarEmpresa() async {
    final data = await traerEmpresaYTrabajador(uidTaxista: widget.taxista.id);

    if (!mounted) return;

    if (data == null) {
      setState(() => _cargando = false);
      return;
    }

    setState(() {
      _empresa = data.empresa; // 👈 ahora tienes la empresa real
      _trabajador = data.trabajador;
      _cargando = false;
    });

    print('💰 Saldo trabajador: ${data.trabajador.saldo}');
    print('📄 Documentos del trabajador: ${data.trabajador.documentos}');
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_empresa == null || _trabajador == null) {
      return const Center(child: Text("No se pudo cargar la información"));
    }

    final empresa = _empresa!;
    final trabajador = _trabajador!;
    final documentos = empresa.documentos;
    final keys = documentos.keys.where((k) => k.startsWith("doc_")).toList()
      ..sort((a, b) {
        final ordenA = (documentos[a]?['orden'] ?? 0).toInt();
        final ordenB = (documentos[b]?['orden'] ?? 0).toInt();
        return ordenA.compareTo(ordenB);
      });

    return ScaffoldConBottom(
      scrollBody: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== Encabezado ======
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'UID: ${widget.taxista.id}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ====== Saldo ======
              SaldoBox(
                moneda: 'ARS',
                saldo: trabajador.saldo,
                onEdit: () async {
                  final cambio = await ModalEditarSaldo.show(
                    context,
                    widget.taxista,
                  );

                  if (cambio != null && mounted) {
                    setState(() {
                      _trabajador = _trabajador!.copyWith(
                        saldo: _trabajador!.saldo + cambio,
                      );
                    });

                    // 🔹 Guardar en la base de datos
                    await ActualizarSaldoTaxista.actualizar(
                      uidTaxista: widget.taxista.id,
                      nuevoSaldo: _trabajador!.saldo,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cambio >= 0
                              ? '✅ Se sumaron ARS ${cambio.toStringAsFixed(2)}'
                              : '❌ Se restaron ARS ${(-cambio).toStringAsFixed(2)}',
                        ),
                        backgroundColor: cambio >= 0
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 14),
              Boton1(
                label: 'Historial de Pagos',
                color: BotonColor.color2,
                borde: BotonBorde.borde2,
                iconoIzquierdo: Icons.route_outlined,
                iconoDerecho: Icons.arrow_forward_ios_rounded,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrir historial (demo UI)')),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Documentos del taxista',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3F3F46),
                ),
              ),
              const SizedBox(height: 12),

              // ====== DIBUJAR TODOS LOS DOCUMENTOS DINÁMICOS ======
              if (keys.isEmpty)
                const Text(
                  'Sin documentos configurados',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...List.generate(keys.length, (i) {
                  final docKey = keys[i];

                  // Documento base (estructura) de la empresa
                  final docEmpresa =
                      (empresa.documentos[docKey] as Map?)
                          ?.cast<String, dynamic>() ??
                      <String, dynamic>{};

                  // Documento real del taxista (campos llenados)
                  final docTaxista =
                      (widget.taxista.misDocumentos?[docKey] as Map?)
                          ?.cast<String, dynamic>() ??
                      <String, dynamic>{};

                  // Documento del trabajador dentro de la empresa (estado, motivo, etc.)
                  final docTrabajador =
                      (_trabajador?.documentos[docKey] as Map?)
                          ?.cast<String, dynamic>() ??
                      <String, dynamic>{};

                  // Estado real del documento (si no hay, queda 'pendiente')
                  final estadoDoc = (docTrabajador['estado'] ?? 'pendiente')
                      .toString();

                  return Column(
                    children: [
                      InfoBox(
                        key: ValueKey('infobox-$docKey-$estadoDoc'),
                        numero: i + 1,
                        titulo:
                            docEmpresa['tituloDoc'] ??
                            'Documento sin título', // ✅ viene de empresa
                        estado: estadoDoc, // valor de muestra
                        actions: [
                          InfoBoxAction(
                            icon: Icons.edit,
                            color: Colors.blue,
                            onTap: () async {
                              final nuevoEstado = await Modular.to.pushNamed(
                                '/validar-documento',
                                arguments: {
                                  'taxista':
                                      widget.taxista, // 👈 objeto del taxista
                                  'empresa':
                                      _empresa, // 👈 objeto de la empresa
                                  'documentoPlantilla':
                                      documentos[docKey], // 👈 doc plantilla
                                  'documentoTaxista':
                                      docTaxista, // 👈 documento actual (doc_1, doc_2, etc.)
                                  'docNombre':
                                      docKey, // 👈 clave del documento actual
                                },
                              );

                              if (nuevoEstado != null && mounted) {
                                setState(() {
                                  // Actualiza en tu modelo (cualquiera de las dos formas sirve)
                                  // 1) Modificando el mapa (rápido):
                                  // (_trabajador!.documentos[docKey] as Map)['estado'] = nuevoEstado;

                                  // 2) Copiando para asegurar nueva referencia (más seguro):
                                  final nuevoDoc = Map<String, dynamic>.from(
                                    _trabajador!.documentos[docKey] ?? {},
                                  )..['estado'] = nuevoEstado;

                                  final nuevosDocumentos =
                                      Map<String, dynamic>.from(
                                        _trabajador!.documentos,
                                      );
                                  nuevosDocumentos[docKey] = nuevoDoc;

                                  _trabajador = TrabajadorEmpresa(
                                    saldo: _trabajador!.saldo,
                                    estadoTaxista: _trabajador!.estadoTaxista,
                                    documentos: nuevosDocumentos,
                                  );
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),

              const SizedBox(height: 16),
              Boton1(
                label: 'Historial de viajes',
                color: BotonColor.color2,
                borde: BotonBorde.borde2,
                iconoIzquierdo: Icons.route_outlined,
                iconoDerecho: Icons.arrow_forward_ios_rounded,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrir historial (demo UI)')),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      btnFijoAbajo: Boton1(
        label: 'Estado del taxista',
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: Icons.traffic_rounded,
        iconoDerecho: Icons.arrow_forward_ios_rounded,
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambiar estado (demo UI)')),
        ),
      ),
    );
  }
}

// ==== UI auxiliar fija (mismo estilo que tu versión) ====

class SaldoBox extends StatelessWidget {
  final String moneda;
  final num saldo;
  final VoidCallback onEdit;

  const SaldoBox({
    super.key,
    this.moneda = 'ARS',
    required this.saldo,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$moneda ${_formatMonto(saldo)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMonto(num value) {
    final str = value.toStringAsFixed(2); // 150.75 -> "150.75"
    final parts = str.split('.');
    final entero = parts[0];
    final dec = parts[1];
    final chars = entero.split('').reversed.toList();
    final buf = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) buf.write(',');
      buf.write(chars[i]);
    }
    final miles = buf.toString().split('').reversed.join();
    return '$miles.$dec';
  }
}

/* EJEMPLO DE USO:
// ⬇️ Caja de saldo
SaldoBox(
  moneda: 'ARS',
  saldo: 500, // 👈 valor inicial pedido
  onEdit: () {
    // aquí puedes abrir tu CajaEdit, modal, etc.
    debugPrint('Editar saldo');
    // Ejemplo simple:
    // CajaEdit.show(context, titulo: 'Editar saldo', valorInicial: '500');
  },
),
const SizedBox(height: 14),
*/

/*
{
  "montoCentavos": 1050,
  "tipo": "recarga",
  "createdAt": "<serverTimestamp>",
  "empresaId": "4VXUTmamByuZaupP7btT",
  "trabajadorId": "1im6GjUrQzVjcjykxejlLdTmHoi1",
  "idempotencyKey": "trabajadorId-2025-09-30T15:42:11Z-xyz",
  "saldoDespues": 250000,
  "descripcion": "Recarga en efectivo",
  "origen": "panel",
  "actorUid": "admin_abc",
  "referencia": "REC-000123",
  "metodo": "efectivo",
  "estado": "confirmado"
}
*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'dart:convert';

import 'package:buses2/shared/widgets/modal_inferior/detalles_usuario.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_servicio.dart';
import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
// 👇 importa tu scaffold con botón fijo
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/modal/modal.dart';       // showAppModal / AppModal
import 'package:buses2/shared/widgets/botones/boton_small.dart'; // BotonSmall
import 'package:buses2/shared/widgets/inputs/input_number.dart';

import 'package:buses2/shared/services/save_traer_firebase/lecturas/doc.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/lecturas_read_repository.dart';

class DetallesTaxistaPage {
  // 👉 queda guardado para usarlo después
  static String? lastUid;
  static void show(
    BuildContext context,
    Map<String, dynamic> perfil, {
    required String uid, // 👈 ahora sí existe el named parameter 'uid'
  }) {
    lastUid = uid; // opcional: queda guardado
    DetallesUsuarioBottomSheet.show(
      context,
      nombre: perfil["nombre"] ?? "Juan Pérez",
      telefono: perfil["telefono"] ?? "+591 70000000",
      correo: perfil["correo"] ?? "juan.perez@mail.com",
      //fotoUrl: perfil["fotoPerfil"] ?? "https://i.pravatar.cc/200?img=5",
      estado: perfil["estado"] ?? "aprobado",
      puntuacion: 4.3,
      headerColors: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
      servicios: const [
        EtiquetaServicio(
          icono: Icons.local_taxi,
          texto: "Taxi",
          color: Colors.yellow,
        ),
      ],

      child: _DetallesContent(uid: uid, perfil: perfil),
    );
  }
}

class _DetallesContent extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> perfil;
  const _DetallesContent({required this.uid, required this.perfil});

  @override
  State<_DetallesContent> createState() => _DetallesContentState();
}

class _DetallesContentState extends State<_DetallesContent> {
  num _saldo = 0;
  final _repo = LecturasReadRepository(); // o inyectado
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarDocs();
  }

  Future<void> _cargarDatos() async {
    final reglas = {
      'empresaID': {'doc': 'pasajeros/{uid}', 'field': 'uidEmpresa'},
    };

    final docs = await DocGets.get(
      absoluteDocPath: ['empresas/{empresaID}/trabajadores/${widget.uid}'],
      nombreMap: ['@root'],
      nombreCampo: [{'saldo'}],
      reglas: reglas,
    );

    final raw = docs.first?['saldo'];
    final num saldo = (raw is num) ? raw : num.tryParse('$raw') ?? 0;

    if (!mounted) return;
    setState(() => _saldo = saldo);
  }

  Future<void> _cargarDocs() async {
    final reglas = {
      'empresaID': {'doc': 'pasajeros/{uid}', 'field': 'uidEmpresa'},
    };

    final docs = await _repo.getAndParse(
      absoluteDocPath: ['empresas/{empresaID}'],
      nombreMap: ['documentos'],
      reglas: reglas,
      parse: ParseOptions(
        nombreMapPadre: 'documentos',
        prefijoClaveHija: 'doc_',
        campoOrden: 'orden',     // se ordena por este campo
        idKey: 'id',
        campos: {
          'tituloDoc': 'tituloDoc', // 👈 solo necesitamos esto (y orden para ordenar)
          'orden': 'orden',
        },
        // sin hijos → puedes omitir children
      ),
    );

    if (!mounted) return;
    setState(() => _items = docs);
  }

  Future<void> _guardarSaldo({
    required String uid,
    required num saldo, // <- recibimos el valor, no el controller
  }) async {
    final reglas = {
      'empresaID': { // placeholder {empresaID}
        'doc': 'pasajeros/{uid}', // doc donde está el campo que queremos leer
        'field': 'uidEmpresa' // campo que contiene el id de la empresa. se puede anidar con 'a-b-c'
      },
    };

    /// Set con merge: actualiza o crea el doc si no existe
    await DocSets.set(
      absoluteDocPath: [
        'empresas/{empresaID}/trabajadores/$uid',
        // 2) Historial (nuevo doc con ID automático por alias 'mov')
        'empresas/{empresaID}/trabajadores/$uid/historial/{newUID:mov}',
      ],
      nombreMap: [
        '@root',
        '@root',
      ],
      data: [
        // 1) Incrementa el saldo actual
        { 'saldo': incrementar(saldo) },
        // 2) Registro de historial
        {
          'monto': saldo,                 // cuánto se agregó
          'tipo': 'recarga',
          //'createdAt': FieldValue.serverTimestamp(),
          'trabajadorId': uid,
          'origen': 'panel',
          // opcionales útiles:
          'descripcion': 'Recarga manual',
          'actorUid': '{uid}',        // si lo tienes a mano
          // 'saldoAntes': _saldo,         // ⚠️ local/optimista
          // 'saldoDespues': _saldo + saldo, // ⚠️ local/optimista
        },
      ],
      reglas: reglas, // 👈 usar placeholder {empresaID}
      autoCreatedAtForNewDocs: true, // Automatico por cada newUID
      createdAtFieldName: 'createdAt', // nombre del campo
      createdAtFor: [false, true], // solo para el 2º ítem
    );
    debugPrint('✅ Saldo guardado para $uid: $saldo');
  }

  void _agregarCredito(BuildContext context, String uid) {
    final formKey = GlobalKey<FormState>();
    final montoCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );

    showAppModal(
      context,
      title: 'Agregar credito',
      showCancel: true,
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NumberInput(
              controller: montoCtrl,
              label: 'Credito a agregar',
              prefixIcon: Icons.account_balance_wallet_outlined,
              allowDecimal: true,
              decimalPlaces: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un monto';
                }
                final v = montoCtrl.numberValue;
                if (v == null) return 'Monto inválido';
                if (v < 1) return 'Debe ser mayor o igual a 1';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa punto o coma para decimales. Se aceptan 2 decimales.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      footerButtons: [
        BotonSmall(
          label: 'Guardar',
          icon: Icons.save,
          onPressed: () async {
            Navigator.of(context).pop(); // 👈 ahora sí cerramos el modal
            
            if (formKey.currentState?.validate() != true) return;

            final v = montoCtrl.numberValue;
            if (v == null) return;

            try {
              await _guardarSaldo(uid: uid, saldo: v);

              if (!mounted) return;
              setState(() => _saldo += v); // 👈 refleja inmediatamente

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saldo actualizado a Bs. ${v.toStringAsFixed(2)}')),
              );
            } catch (e) {
              debugPrint('❌ Error guardando saldo: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error al guardar el saldo')),
              );
            }
          }
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldConBottom(
      scrollBody: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.badge_outlined, size: 18, color: Colors.black54),
                SizedBox(width: 6),
              ]),
              Text('UID: ${widget.uid}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),

              // Saldo REAL (0 si no existe)
              SaldoBox(
                moneda: 'ARS',
                saldo: _saldo,
                onEdit: () => _agregarCredito(context, widget.uid), // usa tu función
              ),

              const SizedBox(height: 14),
              Text(
                'Documentos del taxista',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F3F46),
                    ),
              ),
              const SizedBox(height: 12),

              if (_items.isEmpty)
                const Text('Sin documentos configurados', style: TextStyle(color: Colors.black54))
              else
                ...List.generate(_items.length, (i) {
                  final it = _items[i];
                  return Column(
                    children: [
                      InfoBox(
                        numero: i + 1,
                        titulo: (it['tituloDoc'] ?? '').toString(), // 👈 solo tituloDoc
                        estado: "pendiente", // o según tu lógica
                        actions: [
                          InfoBoxAction(
                            icon: Icons.edit,
                            color: Colors.blue,
                            onTap: () => Modular.to.pushNamed('/validar-documento', arguments: {
                              'id': it['id'],            // si ParseOptions te llena el id
                              'titulo': it['tituloDoc'],
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),

              const SizedBox(height: 16),
              Boton1(
                label: 'Historial de viajes',
                color: BotonColor.color2,
                borde: BotonBorde.borde2,
                iconoIzquierdo: Icons.upload_file,
                iconoDerecho: Icons.upload_file,
                onPressed: () => debugPrint('Botón presionado'),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      btnFijoAbajo: Boton1(
        label: 'Estado del taxista',
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: Icons.upload_file,
        iconoDerecho: Icons.upload_file,
        onPressed: () => debugPrint('Botón presionado'),
      ),
    );
  }
}


// 🎯 1) Widget: tarjeta de saldo
class SaldoBox extends StatelessWidget {
  final String moneda;
  final num saldo;
  final VoidCallback onEdit;

  const SaldoBox({
    super.key,
    this.moneda = 'ARS',
    required this.saldo,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // suave, moderno
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // ícono principal
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 26, color: Colors.white),
          ),
          const SizedBox(width: 12),
          // textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: .2,
                    )),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$moneda ${_formatMonto(saldo)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // botón editar
          Material(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // formatea: 5000 -> 5,000.00
  static String _formatMonto(num value) {
    final str = value.toStringAsFixed(2);
    final parts = str.split('.');
    final entero = parts[0];
    final dec = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      final idx = entero.length - i;
      buffer.write(entero[i]);
      if (idx > 1 && idx % 3 == 1) buffer.write(',');
    }
    return '${buffer.toString()}.$dec';
  }
}

/* EJEMPLO DE USO:
// ⬇️ Caja de saldo
SaldoBox(
  moneda: 'ARS',
  saldo: 500, // 👈 valor inicial pedido
  onEdit: () {
    // aquí puedes abrir tu CajaEdit, modal, etc.
    debugPrint('Editar saldo');
    // Ejemplo simple:
    // CajaEdit.show(context, titulo: 'Editar saldo', valorInicial: '500');
  },
),
const SizedBox(height: 14),
*/


/*
{
  "montoCentavos": 1050,
  "tipo": "recarga",
  "createdAt": "<serverTimestamp>",
  "empresaId": "4VXUTmamByuZaupP7btT",
  "trabajadorId": "1im6GjUrQzVjcjykxejlLdTmHoi1",
  "idempotencyKey": "trabajadorId-2025-09-30T15:42:11Z-xyz",
  "saldoDespues": 250000,
  "descripcion": "Recarga en efectivo",
  "origen": "panel",
  "actorUid": "admin_abc",
  "referencia": "REC-000123",
  "metodo": "efectivo",
  "estado": "confirmado"
}
*/
*/
