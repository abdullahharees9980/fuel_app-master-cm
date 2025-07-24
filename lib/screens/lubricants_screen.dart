// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fuel_app/main.dart';
import 'package:fuel_app/screens/dashboard_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'order_tracking_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LubricantScreen extends StatefulWidget {
  const LubricantScreen({Key? key}) : super(key: key);

  @override
  State<LubricantScreen> createState() => _LubricantScreenState();
}

class _LubricantScreenState extends State<LubricantScreen> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();

  List<DocumentSnapshot> _lubricants = [];
  DocumentSnapshot? _selectedLubricant;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
   bool _hasInternet = true;
  final _quantities = ['1 L', '3 L', '5 L', '10 L', '20 L'];
  String? _selectedQuantity;

  final _paymentTypes = ['Cash', 'Credit Card', 'Online Payment'];
  String? _selectedPaymentType;

  String _cardholderName = '', _cardNumber = '', _expiryDate = '', _cvv = '';
  String _phoneNumber = '';

  bool _loading = false;
  List<_VehicleOption> _options = [];
  int _chosenIndex = 0;

  double _lubricantCost = 0.0;
  final double _deliveryCharge = 5.0;
  double _totalFare = 0.0;

  StreamSubscription<DocumentSnapshot>? _orderListener;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _fetchLubricants();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
  _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  });
}

  @override
  void dispose() {
    _orderListener?.cancel();
    _positionStream?.cancel();
     _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchLubricants() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('lubricants').get();
      if (!mounted) return;
      setState(() {
        _lubricants = snap.docs;
        if (_lubricants.isNotEmpty) _selectedLubricant = _lubricants.first;
      });
    } catch (e) {
      // handle error or show message if needed
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  bool get _isCard => _selectedPaymentType == 'Credit Card';

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location services')),
      );
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(_updateVehicleOptions);
  }

  void _updateVehicleOptions(Position pos) {
    const shopLat = 6.9271, shopLng = 79.8612;
    double distM = Geolocator.distanceBetween(shopLat, shopLng, pos.latitude, pos.longitude);
    double distKm = distM / 1000;

    if (!mounted) return;
    setState(() {
      _options = [
        _VehicleOption('Bike', 2, distKm * 8 + 5),
        _VehicleOption('Threewheel', 3, distKm * 10 + 6),
        _VehicleOption('Car', 4, distKm * 12 + 8),
        _VehicleOption('Van', 5, distKm * 15 + 10),
      ];
      if (_chosenIndex >= _options.length) _chosenIndex = 0;
      _totalFare = _lubricantCost + _options[_chosenIndex].price + _deliveryCharge;
    });
  }

  void _goToVehicleSelection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLubricant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a lubricant')));
      return;
    }
    setState(() => _loading = true);

    final pos = await _determinePosition();
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location services')));
      setState(() => _loading = false);
      return;
    }
    if (_selectedQuantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select quantity')));
      setState(() => _loading = false);
      return;
    }

    final data = _selectedLubricant!.data() as Map<String, dynamic>;
    final raw = data['price'];
    final perL = raw is int ? raw.toDouble() : (raw ?? 0.0);
    double q = double.tryParse(_selectedQuantity!.split(' ')[0]) ?? 0.0;
    _lubricantCost = perL * q;

    _updateVehicleOptions(pos);
    _chosenIndex = 0;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = 1;
    });
    _startLocationUpdates();
  }

  void _bookNow() async {
  setState(() => _loading = true);
  final auth = Provider.of<AuthService>(context, listen: false);
  final user = auth.user;
  if (user == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in')));
    setState(() => _loading = false);
    return;
  }
  final pos = await _determinePosition();
  if (pos == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location services')));
    setState(() => _loading = false);
    return;
  }

  final vehicle = _options[_chosenIndex];
  final data = _selectedLubricant!.data() as Map<String, dynamic>;
  final order = <String, dynamic>{
    'userId': user.uid,
    'userName': user.displayName ?? '',
    'type': 'lubricant',
    'lubricantId': _selectedLubricant!.id,
    'lubricantName': data['name'] ?? '',
    'quantity': double.tryParse(_selectedQuantity!.split(' ')[0]) ?? 0.0,
    'location': GeoPoint(pos.latitude, pos.longitude),
    'pickupLat': pos.latitude,
    'pickupLng': pos.longitude,
    'paymentType': _selectedPaymentType,
    'status': 'process_order',
    'orderTime': FieldValue.serverTimestamp(),
    'vehicle': vehicle.name,
    'eta': vehicle.etaMinutes,
    'price': vehicle.price,
    'deliveryCharge': _deliveryCharge,
    'totalFare': _totalFare,
    'phoneNumber': _phoneNumber.trim(),
    'imgurl': data['imgurl'] ?? '',
  };

  if (_isCard) {
    order.addAll({
      'cardholderName': _cardholderName.trim(),
      'cardNumber': _cardNumber.trim(),
      'expiryDate': _expiryDate.trim(),
      'cvv': _cvv.trim(),
    });
  }

  try {
    final docRef = await FirebaseFirestore.instance.collection('orders').add(order);

    if (!mounted) return;

    Timer? timeoutTimer;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) {
        // Prevent back button while dialog is open
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text('Finding drivers…', style: TextStyle(color: Colors.amber, fontSize: 18)),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Start timeout timer - e.g., 30 seconds
   timeoutTimer = Timer(const Duration(seconds: 30), () {
  timeoutTimer?.cancel();
  _orderListener?.cancel();

  if (!mounted) return;

  Navigator.of(context, rootNavigator: true).pop(); // Close dialog

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => MainScreen()),
    (route) => false,
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Drivers are too busy right now. Please try again later.')),
    );
  });
});
    _orderListener = FirebaseFirestore.instance
        .collection('orders')
        .doc(docRef.id)
        .snapshots()
        .listen((snap) {
      if (snap.data()?['status'] == 'accepted') {
        timeoutTimer?.cancel(); // Cancel timeout if order accepted
        _orderListener?.cancel();

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop(); // Close dialog

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: docRef.id)),
        );
      }
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
  }
}


  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF121212),
    appBar: AppBar(
      title: Text(
        _step == 0 ? 'Order Lubricant' : 'Select Vehicle',
        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFF121212),
      iconTheme: const IconThemeData(color: Colors.amber),
      elevation: 0,
      centerTitle: true,
    ),
    body: Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _lubricants.isEmpty
                ? const Center(child: Text('Loading…', style: TextStyle(color: Colors.amber)))
                : GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.85),
                        child: IntrinsicHeight(
                          child: _step == 0 ? _buildStep1() : _buildStep2(),
                        ),
                      ),
                    ),
                  ),

        // Internet banner
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


  Widget _buildStep1() {
    final lubricantData = _selectedLubricant?.data() as Map<String, dynamic>?;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Select Lubricant'),
          if (lubricantData != null &&
              lubricantData['imgurl'] != null &&
              lubricantData['imgurl'] != '')
          Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.grey[900]!, Colors.grey[850]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.amber.withOpacity(0.2),
        blurRadius: 12,
        spreadRadius: 2,
        offset: Offset(0, 8),
      ),
    ],
  ),
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.only(bottom: 24),
  child: Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          lubricantData['imgurl'],
          height: 140,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.amber, size: 100),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : CircularProgressIndicator(color: Colors.amber),
        ),
      ),
      const SizedBox(height: 10),
   
    ],
  ),
),

          DropdownButtonFormField<DocumentSnapshot>(
            decoration: _inputDecoration(),
            value: _selectedLubricant,
            items: _lubricants
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(
                      (d.data() as Map<String, dynamic>)['name'] ?? '',
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedLubricant = v),
            validator: (v) => v == null ? 'Required' : null,
            dropdownColor: Colors.grey[900],
          ),
          const SizedBox(height: 30),
          _dropdownField('Quantity', _quantities, _selectedQuantity, (v) => setState(() => _selectedQuantity = v)),
          const SizedBox(height: 30),
          _phoneField(),
          const SizedBox(height: 30),
          _dropdownField('Payment Type', _paymentTypes, _selectedPaymentType, (v) => setState(() => _selectedPaymentType = v)),
          if (_isCard) ...[
            const SizedBox(height: 30),
            _buildCardDetailsForm(),
          ],
          const SizedBox(height: 40),
          _actionButton('Next', _goToVehicleSelection),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: _options.length,
            itemBuilder: (_, i) {
              final o = _options[i], sel = i == _chosenIndex;
              return _vehicleCard(o, sel, () {
                setState(() {
                  _chosenIndex = i;
                  _totalFare = _lubricantCost + o.price + _deliveryCharge;
                });
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.amber.withOpacity(0.4), thickness: 1),
        const SizedBox(height: 16),
        _infoText('Delivery Charge', 'LKR ${_deliveryCharge.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        _infoText('Payment Method', _selectedPaymentType ?? 'N/A'),
        const SizedBox(height: 10),
        _infoText('Total Fare', 'LKR ${_totalFare.toStringAsFixed(2)}', isBold: true),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
                child: _actionButton('Back', () => setState(() => _step = 0),
                    background: Colors.amber[700]!)),
            const SizedBox(width: 16),
            Expanded(child: _actionButton('Book Now', _bookNow)),
          ],
        ),
      ],
    );
  }

  Widget _vehicleCard(_VehicleOption o, bool sel, VoidCallback onTap) {
    IconData iconOf(String name) {
      switch (name.toLowerCase()) {
        case 'bike':
          return Icons.motorcycle;
        case 'threewheel':
          return Icons.electric_rickshaw;
        case 'car':
          return Icons.car_rental;
        case 'van':
          return Icons.airport_shuttle;
        default:
          return Icons.local_taxi;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? Colors.amber : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('In ${o.etaMinutes} min',
                style: TextStyle(
                    color: sel ? Colors.black : Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Icon(iconOf(o.name),
                color: sel ? Colors.black : Colors.amber, size: 44),
            Text(o.name,
                style: TextStyle(
                    color: sel ? Colors.black : Colors.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text('LKR ${o.price.toStringAsFixed(2)}',
                style: TextStyle(
                    color: sel ? Colors.black : Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String txt) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          txt,
          style: const TextStyle(
              color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      );

  Widget _dropdownField(
          String label, List<String> items, String? val, ValueChanged<String?> onCh) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.grey[900],
            decoration: _inputDecoration(),
            value: val,
            items: items
                .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w500,
                        ))))
                .toList(),
            onChanged: onCh,
            validator: (v) => v == null ? 'Required' : null,
          ),
        ],
      );

  Widget _phoneField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phone Number',
              style:
                  TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextFormField(
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
            decoration: _inputDecoration(prefix: Icons.phone),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^\d{7,15}$').hasMatch(v.trim())) return 'Invalid';
              return null;
            },
            onChanged: (v) => _phoneNumber = v,
          ),
        ],
      );

  Widget _actionButton(String txt, VoidCallback onTap,
          {Color background = Colors.amber}) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(txt,
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      );

  InputDecoration _inputDecoration({IconData? prefix}) => InputDecoration(
        filled: true,
        fillColor: Colors.grey[900],
        prefixIcon: prefix != null ? Icon(prefix, color: Colors.amber) : null,
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.amber, width: 1.5),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.amber, width: 2),
            borderRadius: BorderRadius.circular(10)),
        errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
            borderRadius: BorderRadius.circular(10)),
        focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
            borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      );

  Widget _infoText(String title, String val, {bool isBold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '$title: $val',
          style: TextStyle(
              color: Colors.amber,
              fontSize: 17,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
        ),
      );

  Widget _buildCardDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Card Details',
            style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
          decoration: _inputDecoration(),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          onChanged: (v) => _cardholderName = v,
        ),
        const SizedBox(height: 20),
        TextFormField(
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
          decoration: _inputDecoration(),
          keyboardType: TextInputType.number,
          maxLength: 19,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final c = v.trim().replaceAll(' ', '');
            if (c.length < 13 || c.length > 19 || !RegExp(r'^\d+$').hasMatch(c))
              return 'Invalid';
            return null;
          },
          onChanged: (v) => _cardNumber = v,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                decoration: _inputDecoration(),
                maxLength: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(v.trim()))
                    return 'MM/YY';
                  return null;
                },
                onChanged: (v) => _expiryDate = v,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                decoration: _inputDecoration(),
                maxLength: 4,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 3 || v.trim().length > 4) return 'Invalid';
                  return null;
                },
                onChanged: (v) => _cvv = v,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleOption {
  final String name;
  final int etaMinutes;
  final double price;
  _VehicleOption(this.name, this.etaMinutes, this.price);
}
