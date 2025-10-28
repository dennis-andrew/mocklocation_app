import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'coordinate_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'enums.dart';
import 'auth_wrapper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static String baseUrl =
      'https://sick-olive-dragon.rootquotient.revolte.io/api/v1/';
  static String socketBaseUrl =
      'https://sick-olive-dragon.rootquotient.revolte.io/';

  TextEditingController textEditingController = TextEditingController();
  TextEditingController incidentIdController = TextEditingController();
  final CoordinateService _coordinateService = CoordinateService();
  final AuthService _authService = AuthService();
  String _statusMessage = 'Not logged in';
  Position? _currentPosition;
  bool _isLoggedIn = false;
  CoordinateType _selectedCoordinateType = CoordinateType.apparatus;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _authService.initialize();
    ApiService().initialize(baseUrl);

    setState(() {
      _isLoggedIn = _authService.isLoggedIn;
      _statusMessage = _isLoggedIn ? 'Ready to start' : 'Please login first';
    });
  }

  Future<void> _startUpdating() async {
    // Check if still logged in (token not expired)
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session expired. Please login again.')),
      );
      AuthService.redirectToLogin(context);
      return;
    }

    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (textEditingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please enter ${_selectedCoordinateType == CoordinateType.apparatus ? 'apparatus' : 'personnel'} ID')),
      );
      return;
    }

    if (_selectedCoordinateType == CoordinateType.personnel &&
        incidentIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter incident ID')),
      );
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Starting...';
      });

      // Final token expiration check before broadcasting coordinates
      if (!_authService.isLoggedIn) {
        await _authService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session expired. Redirecting to login...')),
          );
          AuthService.redirectToLogin(context);
        }
        return;
      }

      int? incidentId;
      if (_selectedCoordinateType == CoordinateType.personnel) {
        incidentId = int.parse(incidentIdController.text);
      }

      await _coordinateService.startUpdatingCoordinates(
        int.parse(textEditingController.text),
        baseUrl,
        socketBaseUrl,
        _selectedCoordinateType,
        incidentId: incidentId,
        context: context,
      );

      setState(() {
        _statusMessage = 'Updating coordinates';
      });

      _startListeningToPositionUpdates();
    } catch (e) {
      String errorMessage = e.toString();

      // Check if it's an authentication error
      if (errorMessage.contains('access token') ||
          errorMessage.contains('unauthorized') ||
          errorMessage.contains('token') ||
          errorMessage.contains('login')) {
        // Clear the session and redirect to login
        await _authService.logout();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session expired. Redirecting to login...')),
          );
          AuthService.redirectToLogin(context);
        }
        return;
      }

      // For other errors, show error message
      setState(() {
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e')),
        );
      }
    }
  }

  Future<void> _stopUpdating() async {
    try {
      setState(() {
        _statusMessage = 'Stopping...';
      });

      await _coordinateService.stopUpdatingCoordinates(
        int.parse(textEditingController.text),
      );

      setState(() {
        _statusMessage = 'Stopped';
        _currentPosition = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error stopping: $e';
      });
    }
  }

  void _startListeningToPositionUpdates() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_coordinateService.isUpdating) {
        timer.cancel();
        if (mounted) {
          setState(() {}); // Refresh UI when stopping
        }
        return;
      }

      final position = _coordinateService.currentPosition;
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _coordinateService.dispose();
    textEditingController.dispose();
    incidentIdController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() {
      _statusMessage = 'Logging out...';
    });

    try {
      await _authService.logout();

      // Stop coordinate updates if running
      if (_coordinateService.isUpdating) {
        final idText = textEditingController.text;
        if (idText.isNotEmpty) {
          await _coordinateService.stopUpdatingCoordinates(
            int.parse(idText),
          );
        }
      }

      // Clear the input fields
      textEditingController.clear();
      incidentIdController.clear();

      if (mounted) {
        // Navigate back to login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during logout: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        title: Text(
          'Mock Location App',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_isLoggedIn)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _logout,
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.logout, size: 20),
                ),
                tooltip: 'Logout',
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // Header section with gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(51)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Return to this app after starting simulation in Lockito app',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main content
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Coordinate Type Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.radio_button_checked,
                                    color: Colors.indigo[600],
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Coordinate Type',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _coordinateService.isUpdating
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedCoordinateType =
                                                  CoordinateType.apparatus;
                                              textEditingController.clear();
                                            });
                                          },
                                    child: Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _selectedCoordinateType ==
                                                CoordinateType.apparatus
                                            ? Colors.indigo[50]
                                            : Colors.grey[50],
                                        border: Border.all(
                                          color: _selectedCoordinateType ==
                                                  CoordinateType.apparatus
                                              ? Colors.indigo[300]!
                                              : Colors.grey[300]!,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.fire_truck,
                                            color: _selectedCoordinateType ==
                                                    CoordinateType.apparatus
                                                ? Colors.indigo[600]
                                                : Colors.grey[500],
                                            size: 24,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Apparatus',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _selectedCoordinateType ==
                                                      CoordinateType.apparatus
                                                  ? Colors.indigo[700]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _coordinateService.isUpdating
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedCoordinateType =
                                                  CoordinateType.personnel;
                                              textEditingController.clear();
                                              incidentIdController.clear();
                                            });
                                          },
                                    child: Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _selectedCoordinateType ==
                                                CoordinateType.personnel
                                            ? Colors.indigo[50]
                                            : Colors.grey[50],
                                        border: Border.all(
                                          color: _selectedCoordinateType ==
                                                  CoordinateType.personnel
                                              ? Colors.indigo[300]!
                                              : Colors.grey[300]!,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: _selectedCoordinateType ==
                                                    CoordinateType.personnel
                                                ? Colors.indigo[600]
                                                : Colors.grey[500],
                                            size: 24,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Personnel',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _selectedCoordinateType ==
                                                      CoordinateType.personnel
                                                  ? Colors.indigo[700]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // ID Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _selectedCoordinateType ==
                                            CoordinateType.apparatus
                                        ? Icons.fire_truck
                                        : Icons.person,
                                    color: Colors.indigo[600],
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '${_selectedCoordinateType == CoordinateType.apparatus ? 'Apparatus' : 'Personnel'} ID',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: textEditingController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Enter ${_selectedCoordinateType == CoordinateType.apparatus ? 'apparatus' : 'personnel'} ID',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.indigo[400]!, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                prefixIcon: Container(
                                  margin: EdgeInsets.all(8),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.tag,
                                    color: Colors.indigo[600],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Incident ID Input Field (only for personnel)
                    if (_selectedCoordinateType == CoordinateType.personnel)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.report_problem,
                                      color: Colors.orange[600],
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Incident ID',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: incidentIdController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter incident ID',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey[300]!, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey[300]!, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.orange[400]!, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  prefixIcon: Container(
                                    margin: EdgeInsets.all(8),
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.numbers,
                                      color: Colors.orange[600],
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_selectedCoordinateType == CoordinateType.personnel)
                      SizedBox(height: 20),
                    // Action Buttons - This should not show since we now handle auth in AuthWrapper

                    if (_isLoggedIn)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _coordinateService.isUpdating
                                    ? null
                                    : _startUpdating,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _coordinateService.isUpdating
                                      ? Colors.grey[300]
                                      : Colors.green[600],
                                  foregroundColor: _coordinateService.isUpdating
                                      ? Colors.grey[600]
                                      : Colors.white,
                                  elevation:
                                      _coordinateService.isUpdating ? 0 : 2,
                                  shadowColor: _coordinateService.isUpdating
                                      ? Colors.transparent
                                      : Colors.green[200],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      size: 20,
                                      color: !_coordinateService.isUpdating
                                          ? Colors.green[200]
                                          : Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Start',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _coordinateService.isUpdating
                                    ? _stopUpdating
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _coordinateService.isUpdating
                                      ? Colors.red[600]
                                      : Colors.grey[300],
                                  foregroundColor: _coordinateService.isUpdating
                                      ? Colors.white
                                      : Colors.grey[600],
                                  elevation:
                                      _coordinateService.isUpdating ? 2 : 0,
                                  shadowColor: _coordinateService.isUpdating
                                      ? Colors.red[200]
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.stop,
                                      size: 20,
                                      color: _coordinateService.isUpdating
                                          ? Colors.red[200]
                                          : Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Stop',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 24),
                    // Status Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Section
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor().withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(),
                                    color: _getStatusColor(),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _statusMessage,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (_isLoggedIn &&
                                _authService.currentUser != null) ...[
                              SizedBox(height: 20),
                              // User Info Section
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo[100],
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.indigo[700],
                                            size: 16,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Logged In AS: ${_authService.currentUser?.firstName ?? 'Unknown'} ${_authService.currentUser?.lastName ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.tag,
                                            color: Colors.orange[700],
                                            size: 16,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${_selectedCoordinateType.name.toUpperCase()} ID: ${textEditingController.text}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 20),
                            // Coordinates Section
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _currentPosition != null
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: _currentPosition != null
                                        ? Colors.green[600]
                                        : Colors.red[600],
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _currentPosition != null
                                            ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                            : 'No coordinates available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _currentPosition != null
                                              ? Colors.green[700]
                                              : Colors.red[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_statusMessage.contains('successful') ||
        _statusMessage.contains('Ready') ||
        _statusMessage.contains('Updating')) {
      return Colors.green[600]!;
    } else if (_statusMessage.contains('error') ||
        _statusMessage.contains('failed')) {
      return Colors.red[600]!;
    } else if (_statusMessage.contains('Logging') ||
        _statusMessage.contains('Starting') ||
        _statusMessage.contains('Stopping')) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon() {
    if (_statusMessage.contains('successful') ||
        _statusMessage.contains('Ready')) {
      return Icons.check_circle;
    } else if (_statusMessage.contains('Updating')) {
      return Icons.gps_fixed;
    } else if (_statusMessage.contains('error') ||
        _statusMessage.contains('failed')) {
      return Icons.error;
    } else if (_statusMessage.contains('Logging') ||
        _statusMessage.contains('Starting') ||
        _statusMessage.contains('Stopping')) {
      return Icons.hourglass_empty;
    } else {
      return Icons.info;
    }
  }
}
