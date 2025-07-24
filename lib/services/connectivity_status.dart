import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectivityService extends ChangeNotifier {
  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  ConnectivityService() {
    _startMonitoring();
  }

  void _startMonitoring() {
    Timer.periodic(Duration(seconds: 5), (_) async {
      try {
        final response = await http
            .get(Uri.parse('https://clients3.google.com/generate_204'))
            .timeout(Duration(seconds: 3));
        final currentStatus = response.statusCode == 204;
        if (_hasConnection != currentStatus) {
          _hasConnection = currentStatus;
          notifyListeners();
        }
      } catch (e) {
        if (_hasConnection != false) {
          _hasConnection = false;
          notifyListeners();
        }
      }
    });
  }
}
