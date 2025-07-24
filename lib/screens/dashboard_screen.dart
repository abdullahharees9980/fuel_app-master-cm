// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fuel_app/screens/order_screen.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'fuel_screen.dart';
import 'lubricants_screen.dart';
import 'breakdown_screen.dart';
import 'order_tracking_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _hasInternet = true;
  late StreamSubscription<ConnectivityResult> _subscription;

  final List<Widget> _pages = [
    DashboardContent(),
    Center(child: Text('Fuel Purchase Screen', style: TextStyle(color: Colors.greenAccent))),
    Center(child: Text('Lubricant Purchase Screen', style: TextStyle(color: Colors.greenAccent))),
    Center(child: Text('Breakdown Service Screen', style: TextStyle(color: Colors.greenAccent))),
    Center(child: Text('Profile Screen', style: TextStyle(color: Colors.greenAccent))),
  ];

  @override
  void initState() {
    super.initState();
    _checkInternet();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _hasInternet = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _checkInternet() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF121212),
    resizeToAvoidBottomInset: false,
    body: Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 10), // spacing from top
            Expanded(
             child: _hasInternet
    ? _pages[_currentIndex]
    : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
            SizedBox(height: 16),
            Text("You're offline", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),

            ),
          ],
        ),

        // This shows a banner inside the app when offline
        if (!_hasInternet)
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              opacity: !_hasInternet ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
              ),
            ),
          ),
          
      ],
    ),
  );
}

}


class DashboardContent extends StatelessWidget {
  Future<String> _fetchUserName(BuildContext context) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;

    if (user == null) return 'User';

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return userDoc.data()?['name'] ?? 'User';
    } catch (_) {
      return 'User';
    }
    
  }
  

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    if (user == null) {
      return const Center(
        child: Text('Please login.', style: TextStyle(color: Colors.amber)),
      );
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('orderTime', descending: true)
        .snapshots();

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _fetchUserName(context),
              builder: (context, snapshot) {
                final name = snapshot.data ?? 'User';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back 👋,',
                        style: GoogleFonts.poppins(
                          color: Colors.amber.shade200,
                          fontSize: 20,
                        )),
                    const SizedBox(height: 4),
                    Text(name,
                        style: GoogleFonts.poppins(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Quick Actions',
                style: GoogleFonts.poppins(
                  color: Colors.amber.shade300,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: screenWidth < 400 ? 1 : 1.2,
              children: [
                 _FeatureCard(
    icon: Icons.local_gas_station,
    title: 'Fuel',
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FuelPurchaseScreen()),
    ),
  ),
  _FeatureCard(
    icon: Icons.build,
    title: 'Breakdown',
    onTap: null, // Enables in Sprint 2
  ),
  _FeatureCard(
    icon: Icons.oil_barrel,
    title: 'Lubricants',
    onTap: null, // Enables in Sprint 3
  ),
  _FeatureCard(
    icon: Icons.list_alt,
    title: 'My Orders',
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderScreen()),
  ),
  )
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Recent Orders',
                    style: GoogleFonts.poppins(
                      color: Colors.amber.shade300,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    )),
                const Icon(Icons.history, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.amber));
                  }

                  final allOrders = snapshot.data?.docs ?? [];
                  final orders = allOrders.where((doc) {
                    final status = (doc['status'] ?? '').toString().toLowerCase();
                    return status.contains('accepted') || status.contains('delivered');
                  }).toList();

                  if (orders.isEmpty) {
                    return Center(
                      child: Text(
                        'No recent completed orders yet',
                        style: GoogleFonts.poppins(
                          color: Colors.amber.shade300,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.amber.withOpacity(0.3)),
                    itemBuilder: (context, index) {
                      final doc = orders[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'Order';
                      final item = data['fuelType'] ?? data['lubricantName'] ?? data['product'] ?? 'Unknown';
                      final quantity = data['quantity']?.toString() ?? '';
                      final status = (data['status'] ?? 'pending').toLowerCase();
                      final timestamp = data['orderTime'] as Timestamp?;
                      final date = timestamp?.toDate() ?? DateTime.now();

                      Color statusColor = Colors.amber;
                      if (status == 'process_order') statusColor = Colors.lightBlueAccent;
                      else if (status == 'picked') statusColor = Colors.orangeAccent;
                      else if (status == 'delivered') statusColor = Colors.greenAccent;
                      else if (status == 'accepted') statusColor = Colors.blueAccent;

                      final ongoingStatuses = ['accepted', 'process_order', 'picked'];

                      return Card(
                        color: const Color(0xFF1F1F1F),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          title: Text(
                            '$type: $item ${quantity.isNotEmpty ? "- $quantity" : ""}',
                            style: GoogleFonts.poppins(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ordered: ${date.toLocal().toString().split('.')[0]}',
                                  style: GoogleFonts.poppins(color: Colors.amber.shade200),
                                ),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: statusColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.local_shipping, color: Colors.amber, size: 28),
                          onTap: ongoingStatuses.contains(status)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderTrackingScreen(orderId: doc.id),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.grey : Colors.amber,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: Colors.black, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

