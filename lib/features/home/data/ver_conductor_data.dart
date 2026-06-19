import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

class VerConductorState {
  final String? driverUid;
  final String? rutaDoc;

  final double? origenLat;
  final double? origenLng;
  final String? origenTexto;

  final double? destinoLat;
  final double? destinoLng;
  final String? destinoTexto;

  final String estadoActual;
  final bool rutaHaciaDestino;

  final bool mapReady;
  final bool arrivedPopupShown;
  final bool passengerOnWayShown;

  final bool initialRouteDrawn;
  final mb.Point? lastDriverPoint;
  final mb.Point? lastObjectivePoint;

  final int? lastRTDBt;
  final DateTime? lastUiUpdate;

  const VerConductorState({
    this.driverUid,
    this.rutaDoc,
    this.origenLat,
    this.origenLng,
    this.origenTexto,
    this.destinoLat,
    this.destinoLng,
    this.destinoTexto,
    this.estadoActual = '',
    this.rutaHaciaDestino = false,
    this.mapReady = false,
    this.arrivedPopupShown = false,
    this.passengerOnWayShown = false,
    this.initialRouteDrawn = false,
    this.lastDriverPoint,
    this.lastObjectivePoint,
    this.lastRTDBt,
    this.lastUiUpdate,
  });

  VerConductorState copyWith({
    String? driverUid,
    String? rutaDoc,
    double? origenLat,
    double? origenLng,
    String? origenTexto,
    double? destinoLat,
    double? destinoLng,
    String? destinoTexto,
    String? estadoActual,
    bool? rutaHaciaDestino,
    bool? mapReady,
    bool? arrivedPopupShown,
    bool? passengerOnWayShown,
    bool? initialRouteDrawn,
    mb.Point? lastDriverPoint,
    mb.Point? lastObjectivePoint,
    int? lastRTDBt,
    DateTime? lastUiUpdate,
  }) {
    return VerConductorState(
      driverUid: driverUid ?? this.driverUid,
      rutaDoc: rutaDoc ?? this.rutaDoc,
      origenLat: origenLat ?? this.origenLat,
      origenLng: origenLng ?? this.origenLng,
      origenTexto: origenTexto ?? this.origenTexto,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      destinoTexto: destinoTexto ?? this.destinoTexto,
      estadoActual: estadoActual ?? this.estadoActual,
      rutaHaciaDestino: rutaHaciaDestino ?? this.rutaHaciaDestino,
      mapReady: mapReady ?? this.mapReady,
      arrivedPopupShown: arrivedPopupShown ?? this.arrivedPopupShown,
      passengerOnWayShown: passengerOnWayShown ?? this.passengerOnWayShown,
      initialRouteDrawn: initialRouteDrawn ?? this.initialRouteDrawn,
      lastDriverPoint: lastDriverPoint ?? this.lastDriverPoint,
      lastObjectivePoint: lastObjectivePoint ?? this.lastObjectivePoint,
      lastRTDBt: lastRTDBt ?? this.lastRTDBt,
      lastUiUpdate: lastUiUpdate ?? this.lastUiUpdate,
    );
  }
}
