import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fuel_app/screens/dashboard_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fuel_app/main_screen.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart';



class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _orderSub;

  LatLng? _dropoffLoc;
  LatLng? _driverLoc;
  String _status = 'process_order';

  List<LatLng> _routePoints = [];

  String? _driverName;
  String? _driverPhone;
  String? _vehicleNo;
   double? _totalFare; 

  String? _estimatedArrival;
String generateCombinedMapUrl() {
  if (_driverLoc == null || _dropoffLoc == null) return '';
  final origin = '${_driverLoc!.latitude},${_driverLoc!.longitude}';
  final destination = '${_dropoffLoc!.latitude},${_dropoffLoc!.longitude}';
  return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';
}
String generateShareMessage() {
  final trackingUrl = 'https://abdullahharees9980.github.io/trackingpage/?orderId=${widget.orderId}';

  return '''
*Fuel Delivery Update*

*Driver:* ${_driverName ?? 'N/A'}
*Phone:* ${_driverPhone ?? 'N/A'}
*Vehicle:* ${_vehicleNo ?? 'N/A'}
*ETA:* ${_estimatedArrival ?? 'N/A'}
*Fare:* Rs ${_totalFare?.toStringAsFixed(2) ?? 'N/A'}

*Track live:* $trackingUrl
''';
}


  static const _apiKey = 'AIzaSyA40-Fss_E_pbEKyCvMJqL_DDJxkAOrdec';



  final Map<String, int> _statusIndex = {
    'process_order': 0,
    'order_picked': 1,
    'order_delivered': 2,
  };

  final List<String> _statusLabels = [
    'Process Order',
    'Order Picked',
    'Order Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _listenOrder();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }
void _shareTrackingDetails() {
  final message = generateShareMessage();
  Share.share(message);
}

void _shareViaWhatsApp() async {
  final message = generateShareMessage(); // uses the tracking page

  final encoded = Uri.encodeComponent(message);
  final url = Uri.parse("whatsapp://send?text=$encoded");

  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication); 
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp is not available')),
    );
  }
}



void _testWhatsAppLaunch() async {
  final url = Uri.parse("whatsapp://send?text=Hello%20from%20Flutter");

  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('WhatsApp not available');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp not found or cannot be launched')),
    );
  }
}




void _shareViaSMS() async {
  final trackingUrl = 'https://abdullahharees9980.github.io/trackingpage/?orderId=${widget.orderId}';
  final message = 'Track your order live here:\n$trackingUrl';

  final smsUri = Uri(
    scheme: 'sms',
    queryParameters: {'body': message},
  );

  if (await canLaunchUrl(smsUri)) {
    await launchUrl(smsUri, mode: LaunchMode.externalApplication);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMS app not available')),
    );
  }
}




  void _listenOrder() {
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
        // Get total fare
      _totalFare = (data['totalFare'] != null) ? (data['totalFare'] as num).toDouble() : null;

      // Existing code...

      if (!mounted) return;
      setState(() {});

      final dp = data['location'] as GeoPoint?;
      if (dp != null && _dropoffLoc == null) {
        _dropoffLoc = LatLng(dp.latitude, dp.longitude);
        _centerMap(_dropoffLoc!);
      }

      final newStatus = (data['status'] as String?) ?? 'process_order';
      if (newStatus != _status) {
        _status = newStatus;
      }

      final driverGeo = data['driverLocation'] as GeoPoint?;
      if (driverGeo != null) {
        _driverLoc = LatLng(driverGeo.latitude, driverGeo.longitude);
        _centerMap(_driverLoc!);
        _updateRoute();
      }

      _driverName = data['driverName'] ?? 'Unknown';
      _driverPhone = data['driverPhone'] ?? 'Unknown';
      _vehicleNo = data['driverVehicle'] ?? 'Unknown';

      final now = DateTime.now();
      final eta = now.add(const Duration(minutes: 15));
      final hour = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
      _estimatedArrival =
          "${hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')} ${eta.hour >= 12 ? 'PM' : 'AM'}";

      if (!mounted) return;
      setState(() {});
    });
  }

  void _centerMap(LatLng loc) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(loc, 13.0),
      );
    }
  }

  Future<void> _updateRoute() async {
    if (_driverLoc == null || _dropoffLoc == null) return;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${_driverLoc!.latitude},${_driverLoc!.longitude}'
      '&destination=${_dropoffLoc!.latitude},${_dropoffLoc!.longitude}'
      '&key=$_apiKey',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) return;

    final body = json.decode(resp.body) as Map<String, dynamic>;
    final routes = body['routes'] as List;
    if (routes.isEmpty) return;

    final encoded = routes[0]['overview_polyline']['points'] as String;
    _routePoints = _decodePolyline(encoded);

    if (!mounted) return;
    setState(() {});
  }

  List<LatLng> _decodePolyline(String str) {
    final List<LatLng> list = [];
    int index = 0, len = str.length, lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      list.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return list;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(telUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $phoneNumber')),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': 'cancelled'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order has been cancelled')),
      );

      // Wait for snackbar to show
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to dashboard
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
        (route) => false,
      );
    }
  }

 @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  final currentIndex = _statusIndex[_status] ?? 0;

  final markers = <Marker>{};
  if (_dropoffLoc != null) {
    markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: _dropoffLoc!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'Drop-off'),
    ));
  }
  if (_driverLoc != null) {
    markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _driverLoc!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Driver'),
    ));
  }

  final polylines = <Polyline>{};
  if (_routePoints.isNotEmpty) {
    polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: _routePoints,
      width: 5,
      color: Colors.amber,
    ));
  }

  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Order Tracking'),
      backgroundColor: Colors.black,
      centerTitle: true,
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(
                    height: isTablet ? 400 : 280,
                    width: double.infinity,
                    child: GoogleMap(
                      onMapCreated: (ctrl) => _mapController = ctrl,
                      initialCameraPosition: CameraPosition(
                        target: _dropoffLoc ?? const LatLng(0, 0),
                        zoom: _dropoffLoc != null ? 13.0 : 2.0,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_driverName != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                      child: Card(
                        color: Colors.grey[900],
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Driver: $_driverName",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: isTablet ? 20 : 18,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text("Phone: $_driverPhone",
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: isTablet ? 18 : 16,
                                        )),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.call, color: Colors.greenAccent),
                                    onPressed: () {
                                      if (_driverPhone != null && _driverPhone != 'Unknown') {
                                        _makePhoneCall(_driverPhone!);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Driver phone number not available')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Text("Vehicle: $_vehicleNo",
                                  style: TextStyle(color: Colors.amber, fontSize: isTablet ? 18 : 16)),
                              if (_estimatedArrival != null) ...[
                                const SizedBox(height: 8),
                                Text("Estimated Arrival: $_estimatedArrival",
                                    style: TextStyle(color: Colors.greenAccent, fontSize: isTablet ? 18 : 16)),
                              ],
                              if (_totalFare != null) ...[
                                const SizedBox(height: 12),
                                Divider(color: Colors.amber.shade300),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Total Fare: \Rs ${_totalFare!.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: isTablet ? 22 : 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 12, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_statusLabels.length, (i) {
                        final done = i <= currentIndex;
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: done ? Colors.amber.shade700 : Colors.grey[850],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: done ? Colors.black : Colors.white,
                                  radius: 14,
                                  child: Icon(
                                    done ? Icons.check : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: done ? Colors.amber : Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _statusLabels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: done ? Colors.black : Colors.grey[400],
                                    fontWeight: FontWeight.bold,
                                    fontSize: isTablet ? 14 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareViaWhatsApp,
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: Size.fromHeight(isTablet ? 54 : 48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareViaSMS,
                            icon: const Icon(Icons.sms, color: Colors.white),
                            label: const Text('SMS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              minimumSize: Size.fromHeight(isTablet ? 54 : 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_status != 'order_delivered' && _status != 'cancelled')
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 8),
                      child: ElevatedButton(
                        onPressed: _status == 'order_picked' ? null : _cancelOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          disabledBackgroundColor: Colors.red.shade200,
                          minimumSize: Size.fromHeight(isTablet ? 54 : 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Cancel Order',
                            style: TextStyle(color: Colors.white, fontSize: isTablet ? 20 : 18)),
                      ),
                    ),

                

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 8),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        minimumSize: Size.fromHeight(isTablet ? 54 : 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Back to Home',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
}