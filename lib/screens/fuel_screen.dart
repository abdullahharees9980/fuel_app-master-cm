  // lib/screens/fuel_purchase_screen.dart

  // ignore_for_file: prefer_const_constructors

  import 'dart:async';

  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/gestures.dart' show OneSequenceGestureRecognizer, EagerGestureRecognizer;
  import 'package:flutter/material.dart';
  import 'package:geolocator/geolocator.dart';
  import 'package:provider/provider.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import '../auth_service.dart';
  import 'order_tracking_screen.dart';
  import 'package:google_maps_flutter/google_maps_flutter.dart';
  import 'package:http/http.dart' as http;



  class FuelSubtype {
    final String name;
    final double priceLKR;

    const FuelSubtype(this.name, this.priceLKR);
    
  }
  StreamSubscription<DocumentSnapshot>? _fuelPriceSubscription;

  class FuelPurchaseScreen extends StatefulWidget {
    const FuelPurchaseScreen({Key? key}) : super(key: key);

    
    @override
    State<FuelPurchaseScreen> createState() => _FuelPurchaseScreenState();
    
    
  }

  class _FuelPurchaseScreenState extends State<FuelPurchaseScreen> {
    
  Widget _customTextField({
    required String label,
    TextEditingController? controller,
    IconData? icon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    TextInputType keyboardType = TextInputType.text,

    
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.amber), // TEXT color
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.amber), // LABEL color
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber, width: 2),
          ),
          prefixIcon: icon != null ? Icon(icon, color: Colors.amber) : null,
        ),
      ),
    );
  }

    int _step = 0;
    final _formKey = GlobalKey<FormState>();
  final TextEditingController _recipientCoordinatesController = TextEditingController();
  TextEditingController _googleMapsLinkController = TextEditingController();


  LatLng? _parseLatLngFromUrl(String url) {
      final latLngRegExp = RegExp(r'/@([-.\d]+),([-.\d]+),');
      final match = latLngRegExp.firstMatch(url);

      if (match != null) {
        final latitude = double.tryParse(match.group(1)!);
        final longitude = double.tryParse(match.group(2)!);

        if (latitude != null && longitude != null) {
          return LatLng(latitude, longitude);
        }
      }
      return null;
    }
    final List<String> _fuelTypes = const ['Diesel', 'Petrol', 'Kerosene'];
    int _selectedFuelIndex = 1;
    late StreamSubscription<ConnectivityResult> _connectivitySubscription;
    bool _hasInternet = true;

    final Map<String, List<FuelSubtype>> fuelOptions = {
      'Diesel': [],
      'Petrol': [],
      'Kerosene': [],
    };

    bool _fuelPricesLoaded = false;
    bool _bookingForSomeoneElse = false;
    FuelSubtype? _selectedFuelSubtype;
    final List<String> _quantities = const ['3 L', '6 L', '8 L', '10 L', '12 L', '16 L', '18 L', '20 L'];
    String? _selectedQuantity;
    final List<String> _paymentTypes = const ['Cash', 'Card'];
    String? _selectedPaymentType;
    Timer? _debounce;
    String _cardholderName = '';
    String _cardNumber = '';
    String _expiryDate = '';
    String _cvv = '';
    String _phoneNumber = '';
    String _recipientName = '';
    String _recipientPhone = '';
    LatLng? _recipientLocation;
    String _recipientLatitude = '';
    String _recipientLongitude = '';

    late GoogleMapController _mapController;
    LatLng _initialPosition = LatLng(6.9271, 79.8612); 


    bool _loading = false;

    List<_VehicleOption> _options = [];
    int _chosenIndex = 0;

    double _fuelCost = 0.0;
    final double _deliveryCharge = 5.0;
    double _totalFare = 0.0;

    StreamSubscription<DocumentSnapshot>? _orderListener;
    StreamSubscription<Position>? _positionStream;

    @override
    void initState() {
      super.initState();
      _listenToFuelPrices();
      _listenToFuelPrices();
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
      // Cancel any active listeners/streams
      _orderListener?.cancel();
      _positionStream?.cancel();
      _fuelPriceSubscription?.cancel();
      _connectivitySubscription.cancel(); // important!
      _googleMapsLinkController.dispose();
      _debounce?.cancel();
      super.dispose();
    }

    void _listenToFuelPrices() {
    _fuelPriceSubscription = FirebaseFirestore.instance
        .collection('fuel_prices')
        .doc('wsyeJiuhfJQccfEaXvYj')
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        _showSnack("Fuel price document not found.");
        return;
      }

      final data = doc.data()!;
      final dieselMap = data['diesel'] as Map<String, dynamic>?;
      final petrolMap = data['petrol'] as Map<String, dynamic>?;
      final keroseneMap = data['kerosene'] as Map<String, dynamic>?;

      if (dieselMap == null || petrolMap == null || keroseneMap == null) {
        _showSnack("Fuel price format invalid in database.");
        return;
      }

      setState(() {
        fuelOptions['Diesel'] = [
          FuelSubtype('Premium', double.tryParse(dieselMap['Premium'] ?? '0') ?? 0),
          FuelSubtype('Regular', double.tryParse(dieselMap['Regular'] ?? '0') ?? 0),
        ];
        fuelOptions['Petrol'] = [
          FuelSubtype('Octane 92', double.tryParse(petrolMap['Octane 92'] ?? '0') ?? 0),
          FuelSubtype('Octane 95', double.tryParse(petrolMap['Octane 95'] ?? '0') ?? 0),
        ];

  fuelOptions['Kerosene'] = [
    FuelSubtype('Industrial Kerosene', double.tryParse(keroseneMap['Industrial Kerosene'] ?? '0') ?? 0),
    FuelSubtype('Lanka Kerosene', double.tryParse(keroseneMap['Lanka Kerosene'] ?? '0') ?? 0),
  ];


        _selectedFuelSubtype = fuelOptions[_fuelTypes[_selectedFuelIndex]]?.first;
        _fuelPricesLoaded = true;
      });
    }, onError: (e) {
      _showSnack("Error loading fuel prices: $e");
    });
  }
  Future<void> handleGoogleMapsLink(String shortUrl) async {
    final resolvedUrl = await resolveGoogleMapsShortLink(shortUrl);

    if (resolvedUrl != null) {
      final coords = extractCoordinatesFromUrl(resolvedUrl);

      if (coords != null) {
        double latitude = coords['lat']!;
        double longitude = coords['lng']!;

        // 👉 You can use these coordinates now!
        print('Latitude: $latitude, Longitude: $longitude');

        // TODO: update your map, form fields, or Firestore data here
      } else {
        print('Coordinates not found in resolved URL.');
      }
    } else {
      print('Could not resolve short URL.');
    }
  }



  Future<String?> resolveGoogleMapsShortLink(String shortUrl) async {
    try {
      final response = await http.get(
        Uri.parse(shortUrl),
        headers: {
   
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                        '(KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
        },
      );

      print('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = response.body;

        final patterns = [
          RegExp(r'href="(https://www\.google\.com/maps/[^"]+)"'),
          RegExp(r'"(https://www\.google\.com/maps/[^"]+)"'),
          RegExp(r'https://www\.google\.com/maps/[^"\s]+'),  
        ];

        for (final regex in patterns) {
          final match = regex.firstMatch(body);
          if (match != null) {
            final foundUrl = match.group(1) ?? match.group(0);
            print('Found URL in body: $foundUrl');
            return foundUrl;
          }
        }
        print('No Google Maps link found in body.');
        return null;
      } else if (response.statusCode == 301 || response.statusCode == 302) {
        // Redirect - get location header
        final location = response.headers['location'];
        print('Redirect location: $location');
        return location;
      } else {
        print('Unexpected status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error resolving short URL: $e');
      return null;
    }
  }



  Map<String, double>? extractCoordinatesFromUrl(String url) {
    final regex = RegExp(r'/@(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = regex.firstMatch(url);

    if (match != null) {
      final lat = double.parse(match.group(1)!);
      final lng = double.parse(match.group(2)!);
      return {'lat': lat, 'lng': lng};
    }

    return null;
  }

    Future<Position?> _determinePosition() async {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition();
    }

    bool get _isCardPayment => _selectedPaymentType == 'Card';

    void _startLocationUpdates() async {
      // Cancel any existing position stream
      await _positionStream?.cancel();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Enable location services');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied');
        return;
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        _updatePrices(pos);
      });
    }

    void _updatePrices(Position pos) {
      const originLat = 6.9271;
      const originLng = 79.8612;

      double distanceInMeters = Geolocator.distanceBetween(
          originLat, originLng, pos.latitude, pos.longitude);
      double distanceKm = distanceInMeters / 1000;

      setState(() {
        _options = [
          _VehicleOption(name: 'Bike', etaMinutes: 2, price: distanceKm * 8 + 5),
          _VehicleOption(name: 'Threewheel', etaMinutes: 3, price: distanceKm * 10 + 6),
          _VehicleOption(name: 'Car', etaMinutes: 4, price: distanceKm * 12 + 8),
          _VehicleOption(name: 'Van', etaMinutes: 5, price: distanceKm * 15 + 10),
        ];

        if (_chosenIndex >= _options.length) _chosenIndex = 0;

        _totalFare = _fuelCost + _options[_chosenIndex].price + _deliveryCharge;
      });
    }

  void _goToVehicleSelection() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedQuantity == null || _selectedFuelSubtype == null) {
      _showSnack('Please select quantity and fuel type');
      return;
    }

    if (_bookingForSomeoneElse) {
      if (_recipientName.trim().isEmpty) {
        _showSnack('Please enter recipient name');
        return;
      }

      if (!RegExp(r'^(?:\+94|94|0)?7\d{8}$').hasMatch(_recipientPhone.trim())) {
        _showSnack('Please enter a valid recipient phone number');
        return;
      }

      // Validate latitude and longitude inputs
    final coordinates = _recipientCoordinatesController.text.split(',');
  if (coordinates.length != 2) {
    _showSnack('Please enter valid coordinates in format: latitude, longitude');
    return;
  }

  final lat = double.tryParse(coordinates[0].trim());
  final lng = double.tryParse(coordinates[1].trim());


      if (lat == null || lat < -90 || lat > 90) {
        _showSnack('Please enter a valid latitude between -90 and 90');
        return;
      }
      if (lng == null || lng < -180 || lng > 180) {
        _showSnack('Please enter a valid longitude between -180 and 180');
        return;
      }

    
    _recipientLatitude = lat.toString();
  _recipientLongitude = lng.toString();
  _recipientLocation = LatLng(lat, lng);
    }
  

    setState(() => _loading = true);

    final pos = await _determinePosition();

    if (pos == null) {
      _showSnack('Enable location services');
      setState(() => _loading = false);
      return;
    }

    final qtyLiters = double.tryParse(_selectedQuantity!.split(' ')[0]) ?? 0;
    _fuelCost = qtyLiters * _selectedFuelSubtype!.priceLKR;

    _updatePrices(pos);
    _chosenIndex = 0;

    setState(() {
      _loading = false;
      _step = 1;
    });

    _startLocationUpdates();
  }



    void _bookNow() async {
      FocusScope.of(context).unfocus();

      setState(() => _loading = true);

      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.user!;
      final userId = user.uid;
      final userName = user.displayName ?? 'Unknown';

      final pos = await _determinePosition();
      if (pos == null) {
        _showSnack('Enable location services');
        setState(() => _loading = false);
        return;
      }

      final vehicle = _options[_chosenIndex];

  final GeoPoint locationPoint = _bookingForSomeoneElse && _recipientLocation != null
    ? GeoPoint(_recipientLocation!.latitude, _recipientLocation!.longitude)
    : GeoPoint(pos.latitude, pos.longitude);

  final orderData = {
    'userId': userId,
    'userName': userName,
    'type': 'fuel',
    'fuelType': _fuelTypes[_selectedFuelIndex],
    'fuelSubtype': _selectedFuelSubtype?.name ?? '',
    'quantity': double.parse(_selectedQuantity!.split(' ')[0]),
    'location': locationPoint,
    'pickupLat': locationPoint.latitude,
    'pickupLng': locationPoint.longitude,
    'paymentType': _selectedPaymentType,
    'status': 'process_order',
    'orderTime': FieldValue.serverTimestamp(),
    'vehicle': vehicle.name,
    'eta': vehicle.etaMinutes,
    'price': vehicle.price,
    'deliveryCharge': _deliveryCharge,
    'totalFare': _totalFare,
    'phoneNumber': _bookingForSomeoneElse ? _recipientPhone.trim() : _phoneNumber.trim(),
    'recipientName': _bookingForSomeoneElse ? _recipientName.trim() : '',
    'isBookingForOther': _bookingForSomeoneElse,
  };


      if (_isCardPayment) {
        orderData.addAll({
          'cardholderName': _cardholderName.trim(),
          'cardNumber': _cardNumber.trim(),
          'expiryDate': _expiryDate.trim(),
          'cvv': _cvv.trim(),
        });
      }

      try {
        final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

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
                    Text('Finding drivers…', style: TextStyle(color: Colors.amber, fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        );

        Timer timeoutTimer = Timer(const Duration(seconds: 30), () {
          _orderListener?.cancel();
          if (mounted) {
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pop(); // back to dashboard
            _showSnack('Drivers are too busy right now. Please try again later.');
            setState(() => _loading = false);
          }
        });

        _orderListener = FirebaseFirestore.instance
            .collection('orders')
            .doc(docRef.id)
            .snapshots()
            .listen((snap) {
          final data = snap.data();
          if (data == null) return;
          if (data['status'] == 'accepted') {
            timeoutTimer.cancel();
            _orderListener?.cancel();
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: docRef.id)),
            );
          }
        });
      } catch (e) {
        setState(() => _loading = false);
        _showSnack('Booking failed: \$e');
      }
    }

    void _showSnack(String msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: Text(
            _step == 0 ? 'Purchase Fuel' : 'Select Vehicle',
            style: const TextStyle(color: Colors.amber),
          ),
          backgroundColor: const Color(0xFF121212),
          iconTheme: const IconThemeData(color: Colors.amber),
        ),
    body: Stack(
    children: [
      !_fuelPricesLoaded
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
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
    final fuelCategory = _fuelTypes[_selectedFuelIndex];
    final subtypeOptions = fuelOptions[fuelCategory]!;

    if (_selectedFuelSubtype == null || !subtypeOptions.contains(_selectedFuelSubtype)) {
      _selectedFuelSubtype = subtypeOptions.first;
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildSectionCard(
            title: "Booking For",
            child: SwitchListTile(
    title: Text("Book for someone else?", style: TextStyle(color: Colors.amber)),
    value: _bookingForSomeoneElse,
    activeColor: Colors.grey.shade700,                // Thumb color when ON
    activeTrackColor: Colors.amber.shade200,  // Track color when ON
    inactiveThumbColor: Colors.grey,          // Optional: Thumb color when OFF
    inactiveTrackColor: Colors.grey.shade700, // Optional: Track color when OFF
    onChanged: (value) {
      setState(() {
        _bookingForSomeoneElse = value;
        if (!value) {
          _recipientName = '';
          _recipientPhone = '';
          _recipientCoordinatesController.clear();
          _recipientLocation = null;
        }
      });
    },
  ),
          ),

          if (_bookingForSomeoneElse)
            _buildSectionCard(
              title: "Recipient Info",
              child: Column(
                children: [
                  _customTextField(
                    label: "Recipient's Name",
                    icon: Icons.person,
                    onChanged: (v) => _recipientName = v,
                    validator: (v) => v!.trim().isEmpty ? 'Enter recipient name' : null,
                  ),
                  SizedBox(height: 16),
                  _customTextField(
                    label: "Recipient's Phone",
                    icon: Icons.phone,
                    onChanged: (v) => _recipientPhone = v,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter recipient phone number';
                      if (!RegExp(r'^(?:\+94|94|0)?7\d{8}$').hasMatch(v.trim())) {
                        return 'Enter valid recipient phone number';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
              _customTextField(
    controller: _googleMapsLinkController,
    label: "Google Maps Share Link",
    icon: Icons.link,
    keyboardType: TextInputType.url,
 onChanged: (link) async {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  _debounce = Timer(const Duration(milliseconds: 500), () async {
    if (link.trim().isEmpty) return;

    final resolvedUrl = await resolveGoogleMapsShortLink(link.trim());
    if (resolvedUrl == null) {
      _showSnack('Could not resolve the shared Google Maps link.');
      return;
    }

    final latLng = _parseLatLngFromUrl(resolvedUrl);
    if (latLng == null) {
      _showSnack('Could not extract location from the link.');
      return;
    }

    setState(() {
      _recipientLocation = latLng;
      _recipientCoordinatesController.text =
          '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
    });

    if (_mapController != null) {
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    }
  });
},

    validator: (v) {
      if (_bookingForSomeoneElse && (v == null || v.trim().isEmpty)) {
        return 'Enter Google Maps share link';
      }
      return null;
    },
  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 15,
                      ),
                      onMapCreated: (controller) => _mapController = controller,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                      },
                      onTap: (LatLng pos) {
                        setState(() {
                          _recipientLocation = pos;
                          _recipientCoordinatesController.text =
                              '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
                        });
                      },
                      markers: _recipientLocation != null
                          ? {
                              Marker(
                                markerId: MarkerId("recipient"),
                                position: _recipientLocation!,
                              ),
                            }
                          : {},
                    ),
                  ),
                ],
              ),
            ),

      _buildSectionCard(
    title: "Fuel Selection ",
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fuel Selection widgets
        _buildFuelTypeToggle(),
        const SizedBox(height: 20),
        _dropdownField(
          'Select Fuel Type',
          subtypeOptions.map((f) => '${f.name} - LKR ${f.priceLKR.toStringAsFixed(2)}').toList(),
          _selectedFuelSubtype != null
              ? '${_selectedFuelSubtype!.name} - LKR ${_selectedFuelSubtype!.priceLKR.toStringAsFixed(2)}'
              : null,
          (val) {
            final index = subtypeOptions.indexWhere((f) => val?.startsWith(f.name) ?? false);
            if (index >= 0) {
              setState(() {
                _selectedFuelSubtype = subtypeOptions[index];
              });
            }
          },
        ),
        const SizedBox(height: 16),
        _dropdownField('Select Quantity', _quantities, _selectedQuantity,
            (v) => setState(() => _selectedQuantity = v)),

        const SizedBox(height: 32),

        // Your Info widgets
        _phoneField(),
        const SizedBox(height: 16),
        _dropdownField(
          'Payment Type',
          _paymentTypes,
          _selectedPaymentType,
          (v) => setState(() => _selectedPaymentType = v),
        ),
        if (_isCardPayment) ...[
          const SizedBox(height: 16),
          _buildCardDetailsForm(),
        ],
      ],
    ),
  ),


          const SizedBox(height: 24),
          _actionButton('Next', _goToVehicleSelection, disabled: _loading),
        ],
      ),
    );
  }



  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }



    Widget _buildStep2() {
      return Column(
        children: [
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _options.length,
              itemBuilder: (ctx, i) {
                final o = _options[i], sel = i == _chosenIndex;
                return _vehicleCard(o, sel, () {
                  setState(() {
                    _chosenIndex = i;
                    _totalFare = _fuelCost + o.price + _deliveryCharge;
                  });
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          _infoText('Payment Method', _selectedPaymentType ?? 'N/A'),
          const SizedBox(height: 8),
          _infoText('Total Fare', 'LKR ${_totalFare.toStringAsFixed(2)}', isBold: true),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _actionButton('Back', () => setState(() => _step = 0), background: Colors.amber[700]!)),
              const SizedBox(width: 12),
              Expanded(child: _actionButton('Book Now', _bookNow, disabled: _loading)),
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
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'In ${o.etaMinutes} min',
                style: TextStyle(
                  color: sel ? Colors.black : Colors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              iconOf(o.name),
              color: sel ? Colors.black : Colors.amber,
              size: 44,
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  o.name,
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'LKR ${o.price.toStringAsFixed(2)}',
                style: TextStyle(
                  color: sel ? Colors.black : Colors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _sectionTitle(String text) => Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: const TextStyle(color: Colors.amber, fontSize: 18)),
        );

  Widget _buildFuelTypeToggle() {
    IconData _getFuelIcon(String fuel) {
      switch (fuel.toLowerCase()) {
        case 'diesel':
          return Icons.local_gas_station;
        case 'petrol':
          return Icons.ev_station;
        case 'kerosene':
          return Icons.fireplace;
        default:
          return Icons.local_gas_station;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_fuelTypes.length, (i) {
        final selected = i == _selectedFuelIndex;
        final fuelType = _fuelTypes[i];

        return GestureDetector(
          onTap: () => setState(() {
            _selectedFuelIndex = i;
            _selectedFuelSubtype = fuelOptions[fuelType]!.first;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? Colors.amber : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber, width: 1.5),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : [],
            ),
            width: 100,
            height: 110,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getFuelIcon(fuelType),
                  color: selected ? Colors.black : Colors.amber,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  fuelType,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }


    Widget _dropdownField(String label, List<String> items, String? value, ValueChanged<String?> onChange) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.amber, fontSize: 18)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.grey[900],
            decoration: _inputDecoration(),
            value: value,
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(color: Colors.amber))))
                .toList(),
            onChanged: onChange,
            validator: (v) => v == null ? 'Required' : null,
          ),
        ],
      );
    }

    Widget _phoneField() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phone Number', style: TextStyle(color: Colors.amber, fontSize: 18)),
            const SizedBox(height: 8),
            TextFormField(
              style: const TextStyle(color: Colors.amber),
              decoration: _inputDecoration(prefix: Icons.phone),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter phone number';
                if (!RegExp(r'^(?:\+94|94|0)?7\d{8}$').hasMatch(v.trim())) {
    return 'Enter valid  phone number';
  }
              },
              onChanged: (v) => _phoneNumber = v,
            ),
          ],
        );

    Widget _actionButton(String text, VoidCallback onTap, {Color background = Colors.amber, bool disabled = false}) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: disabled ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: disabled ? Colors.amber.withOpacity(0.5) : background,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 18)),
        ),
      );
    }

    InputDecoration _inputDecoration({IconData? prefix}) {
      return InputDecoration(
        filled: true,
        fillColor: Colors.grey[900],
        prefixIcon: prefix != null ? Icon(prefix, color: Colors.amber) : null,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.amber),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.amber, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        counterText: '',
      );
    }

    Widget _infoText(String title, String value, {bool isBold = false}) {
      return Text(
        '$title: $value',
        style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      );
    }

    Widget _buildCardDetailsForm() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Details', style: TextStyle(color: Colors.amber, fontSize: 18)),
          const SizedBox(height: 8),
          TextFormField(
            style: const TextStyle(color: Colors.amber),
            decoration: _inputDecoration(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter cardholder name' : null,
            onChanged: (v) => _cardholderName = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: const TextStyle(color: Colors.amber),
            decoration: _inputDecoration(),
            keyboardType: TextInputType.number,
            maxLength: 19,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter card number';
              final c = v.trim().replaceAll(' ', '');
              if (c.length < 13 || c.length > 19 || !RegExp(r'^\d+$').hasMatch(c)) return 'Invalid card number';
              return null;
            },
            onChanged: (v) => _cardNumber = v,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  style: const TextStyle(color: Colors.amber),
                  decoration: _inputDecoration(),
                  maxLength: 5,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter expiry';
                    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(v.trim())) return 'MM/YY';
                    return null;
                  },
                  onChanged: (v) => _expiryDate = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  style: const TextStyle(color: Colors.amber),
                  decoration: _inputDecoration(),
                  maxLength: 4,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter CVV';
                    if (v.trim().length < 3 || v.trim().length > 4) return 'Invalid CVV';
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
    const _VehicleOption({required this.name, required this.etaMinutes, required this.price});
  }
