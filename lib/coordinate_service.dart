import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'socket_connection.dart';
import 'enums.dart';
import 'services/auth_service.dart';

class CoordinateService {
  static final CoordinateService _instance = CoordinateService._internal();
  factory CoordinateService() => _instance;
  CoordinateService._internal();

  SocketService socketService = SocketService.instance;
  StreamSubscription<Position>? _positionStream;
  bool _isUpdating = false;
  Position? _currentPosition;
  CoordinateType? _currentCoordinateType;

  bool get isUpdating => _isUpdating;
  Position? get currentPosition => _currentPosition;

  Future<bool> _hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startUpdatingCoordinates(int id, String baseUrl,
      String socketBaseUrl, CoordinateType coordinateType,
      {int? incidentId}) async {
    if (_isUpdating) {
      log('Already updating coordinates');
      return;
    }

    final bool hasPermission = await _hasLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    final AuthService authService = AuthService();
    final String? accessToken = authService.currentToken?.accessToken;

    if (accessToken == null) {
      throw Exception('No access token available. Please login first.');
    }

    try {
      if (!socketService.isInitialized) {
        await socketService.initialize(baseUrl, socketBaseUrl, accessToken);
      }

      if (coordinateType == CoordinateType.apparatus) {
        socketService.emit(SocketRoomAction.JoinApparatus.value, {
          'apparatusId': id,
        });
      } else {
        socketService.emit(SocketRoomAction.JoinPersonnel.value, {
          'personnelId': id,
        });
      }

      final Position initialPosition = await Geolocator.getCurrentPosition();
      _currentPosition = initialPosition;
      _currentCoordinateType = coordinateType;
      _emitCoordinates(id, initialPosition, coordinateType,
          incidentId: incidentId);

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        log('Updated coordinates: ${position.latitude}, ${position.longitude}');
        _currentPosition = position;
        _emitCoordinates(id, position, coordinateType, incidentId: incidentId);
      });

      _isUpdating = true;
      log('Started updating coordinates for ${coordinateType == CoordinateType.apparatus ? 'apparatus' : 'personnel'}: $id');
    } catch (e) {
      log('Error starting coordinate updates: $e');
      throw Exception('Failed to start coordinate updates: $e');
    }
  }

  void _emitCoordinates(
      int id, Position position, CoordinateType coordinateType,
      {int? incidentId}) {
    log('////////////mocking ${coordinateType == CoordinateType.apparatus ? 'apparatus' : 'personnel'} id : $id');

    if (coordinateType == CoordinateType.apparatus) {
      socketService.emit(SocketActionName.ApparatusUpdate.value, {
        'action': SocketActionName.ApparatusCoordsUpdate.value,
        'data': {
          'apparatus': {
            'id': id,
            'latitude': position.latitude,
            'longitude': position.longitude,
          }
        }
      });
    } else {
      socketService.emit(SocketActionName.PersonnelUpdate.value, {
        'action': SocketActionName.PersonnelCoordsUpdate.value,
        'data': {
          'personnel': {
            'id': id,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'incidentId': incidentId,
          }
        }
      });
    }
  }

  Future<void> stopUpdatingCoordinates(int id) async {
    if (!_isUpdating) {
      log('Not currently updating coordinates');
      return;
    }

    try {
      if (_currentCoordinateType == CoordinateType.apparatus) {
        socketService.emit(SocketRoomAction.LeaveApparatus.value, {
          'apparatusId': id,
        });
      } else {
        socketService.emit(SocketRoomAction.LeavePersonnel.value, {
          'personnelId': id,
        });
      }

      await _positionStream?.cancel();
      _positionStream = null;
      _isUpdating = false;
      _currentCoordinateType = null;

      log('Stopped updating coordinates for ${_currentCoordinateType == CoordinateType.apparatus ? 'apparatus' : 'personnel'}: $id');
    } catch (e) {
      log('Error stopping coordinate updates: $e');
    }
  }

  void dispose() {
    _positionStream?.cancel();
    _positionStream = null;
    _isUpdating = false;
    _currentPosition = null;
    _currentCoordinateType = null;
  }
}
