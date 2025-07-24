// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'order_tracking_screen.dart';

class OrderScreen extends StatefulWidget {
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _hasInternet = result != ConnectivityResult.none;
      });
    });

    // Initial check
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _hasInternet = result != ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders', style: TextStyle(color: Colors.amber)),
          backgroundColor: Colors.black,
        ),
        backgroundColor: Colors.black,
        body: const Center(child: Text('Please login.', style: TextStyle(color: Colors.amber))),
      );
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('orderTime', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: Colors.amber)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: ordersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.redAccent)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }

              final orders = (snapshot.data?.docs ?? []).where((doc) {
                final status = (doc['status'] ?? '').toString().toLowerCase();
                return status != 'process_order';
              }).toList();

              if (orders.isEmpty) {
                return const Center(
                  child: Text(
                    'No orders found.',
                    style: TextStyle(color: Colors.amber, fontSize: 18),
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
                    color: Colors.grey[900],
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      title: Text(
                        '$type: $item ${quantity.isNotEmpty ? "- $quantity" : ""}',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ordered: ${date.toLocal().toString().split('.')[0]}',
                                style: TextStyle(color: Colors.amber.shade200)),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(status.toUpperCase(),
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                child: Container(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
