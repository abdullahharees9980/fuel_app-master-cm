// Keep your current imports
// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fuel_app/main.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'order_tracking_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BreakdownScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  const BreakdownScreen({Key? key, this.onNavigateToDashboard}) : super(key: key);

  @override
  State<BreakdownScreen> createState() => _BreakdownScreenState();
}

class _BreakdownScreenState extends State<BreakdownScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVehicle;
  String _problemDescription = '';
  String _phoneNumber = '';
  String? _urgency;
  String? _paymentType;
  int _price = 0;
  bool _loading = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
   bool _hasInternet = true;

  final List<String> _vehicles = [
    // Cars
  'Toyota Corolla',
  'Toyota Prius',
  'Toyota Land Cruiser',
  'Honda Civic',
  'Honda Vezel',
  'Honda CR-V',
  'Nissan X-Trail',
  'Nissan Juke',
  'Suzuki Swift',
  'Suzuki Alto',
  'Mitsubishi Pajero',
  'Mitsubishi Lancer',
  'Isuzu D-Max',
  'Mahindra Scorpio',
  'Hyundai Tucson',
  'Hyundai Santa Fe',
  'Kia Sportage',
  'Ford Ranger',
  'BMW X5',
  'Audi Q5',
  'Mercedes-Benz C-Class',
  'Tesla Model 3',
  'Jeep Wrangler',
  'Tata Indica',  
  'Land Rover Defender',
  'Volvo XC90',
  'Mazda CX-5',
  'Subaru Forester',

  // Bikes / Motorcycles
  'Honda CG125',
  'Honda CB150F',
  'Yamaha FZ-S',
  'Bajaj Pulsar NS160',
  'TVS Apache RTR 160',
  'Suzuki Gixxer SF',
  'KTM Duke 200',
  'Hero Splendor Plus',
  'Royal Enfield Classic 350',
  'Honda Dio',

  // Three-Wheelers (Tuk-Tuks)
  'Bajaj RE',
  'Piaggio Ape',
  'TVS King',
  'Mahindra Treo',
  'Kinetic Safar',];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];
  final List<String> _paymentOptions = ['Cash'];

  StreamSubscription<DocumentSnapshot>? _orderListener;
  Timer? _timeoutTimer;

  int _calculatePrice(String? urgency) {
    switch (urgency) {
      case 'Low': return 1000;
      case 'Medium': return 2000;
      case 'High': return 3000;
      default: return 0;
    }
    
  }
@override
void initState() {
  super.initState();
  _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((ConnectivityResult result) {
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  });

  // Check initial status
  Connectivity().checkConnectivity().then((result) {
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  });
}



  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10));
    } catch (e) {
      print('Failed to get position: $e');
      return null;
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;

    final pos = await _determinePosition();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location services and grant permission')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    final orderData = {
      'userId': user?.uid ?? 'anonymous',
      'userName': user?.displayName ?? 'Unknown',
      'type': 'breakdown',
      'vehicle': _selectedVehicle,
      'problemDescription': _problemDescription.trim(),
      'urgency': _urgency,
      'paymentType': _paymentType,
      'price': _price,
      'status': 'process_order',
      'orderTime': FieldValue.serverTimestamp(),
      'pickupLat': pos.latitude,
      'pickupLng': pos.longitude,
      'location': GeoPoint(pos.latitude, pos.longitude),
      'phoneNumber': _phoneNumber.trim(),
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text('Waiting for a mechanic to accept...', style: TextStyle(color: Colors.amber)),
                ],
              ),
            ),
          ),
        ),
      );

      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        _orderListener?.cancel();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainScreen()), (route) => false);
      });

      _orderListener = FirebaseFirestore.instance
          .collection('orders')
          .doc(docRef.id)
          .snapshots()
          .listen((docSnap) {
        if (docSnap.exists && docSnap.data()?['status'] == 'accepted') {
          _timeoutTimer?.cancel();
          _orderListener?.cancel();
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: docRef.id)),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit request: $e')));
      }
    }
  }

  @override
  void dispose() {
    _orderListener?.cancel();
    _timeoutTimer?.cancel();
     _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF121212),
    appBar: AppBar(
      title: const Text('Hire Breakdown Service', style: TextStyle(color: Colors.amber)),
      backgroundColor: const Color(0xFF121212),
      iconTheme: const IconThemeData(color: Colors.amber),
    ),
    body: Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _sectionTitle('Select Vehicle'),
                      const SizedBox(height: 8),
                      DropdownSearch<String>(
                        items: _vehicles,
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.amber),
                            decoration: InputDecoration(
                              hintText: 'Search vehicle...',
                              hintStyle: TextStyle(color: Colors.amberAccent),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.amber),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.amber),
                              ),
                            ),
                          ),
                          itemBuilder: (context, item, isSelected) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Text(item, style: TextStyle(color: Colors.amber)),
                          ),
                          menuProps: MenuProps(
                            backgroundColor: Colors.grey[900],
                          ),
                        ),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: _inputDecoration(hint: 'Select your vehicle'),
                        ),
                        selectedItem: _selectedVehicle,
                        onChanged: (val) => setState(() => _selectedVehicle = val),
                        validator: (val) => val == null || val.isEmpty ? 'Please select a vehicle' : null,
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('Describe the Problem'),
                      const SizedBox(height: 8),
                      TextFormField(
                        maxLines: 4,
                        style: const TextStyle(color: Colors.amber),
                        decoration: _inputDecoration(hint: 'E.g., engine won’t start'),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Please describe the problem' : null,
                        onChanged: (val) => _problemDescription = val,
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('Phone Number'),
                      const SizedBox(height: 8),
                      TextFormField(
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.amber),
                        decoration: _inputDecoration(hint: 'Enter your phone number'),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter your phone number';
                          final phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
                          if (!phoneRegExp.hasMatch(val.trim())) return 'Enter a valid phone number';
                          return null;
                        },
                        onChanged: (val) => _phoneNumber = val,
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('Urgency Level'),
                      const SizedBox(height: 8),
                      _dropdownField(
                        _urgencyLevels,
                        _urgency,
                        (val) {
                          setState(() {
                            _urgency = val;
                            _price = _calculatePrice(val);
                          });
                        },
                        'Please select urgency level',
                      ),

                      const SizedBox(height: 24),
                      _sectionTitle('Payment Method'),
                      const SizedBox(height: 8),
                      _dropdownField(
                        _paymentOptions,
                        _paymentType,
                        (val) => setState(() => _paymentType = val),
                        'Please select payment method',
                      ),

                      const SizedBox(height: 24),
                      Text('Estimated Price: LKR $_price',
                          style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 36),
                      _actionButton('Submit Request', _submitRequest),
                    ],
                  ),
                ),
              ),

        // INTERNET BANNER
        if (!_hasInternet)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Colors.red.shade700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // OVERLAY TO BLOCK INTERACTION
        if (!_hasInternet)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black54,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(
      color: Colors.amber,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  ),
);
Widget _dropdownField(
  List<String> items,
  String? value,
  ValueChanged<String?> onChanged,
  String validationMsg,
) {
  return DropdownButtonFormField<String>(
    decoration: _inputDecoration(),
    dropdownColor: Colors.grey[900],
    borderRadius: BorderRadius.circular(12),
    value: value,
    icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
    items: items.map(
      (item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(color: Colors.amber)),
      ),
    ).toList(),
    onChanged: onChanged,
    validator: (val) => val == null ? validationMsg : null,
  );
}

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.grey[850],
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.amberAccent),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.amber),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.amber, width: 1.5),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

Widget _actionButton(String text, VoidCallback onTap) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 5,
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

  }
