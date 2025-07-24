// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../auth_service.dart';

// class RegistrationScreen extends StatefulWidget {
//   static const routeName = '/register';
//   const RegistrationScreen({Key? key}) : super(key: key);

//   @override
//   State<RegistrationScreen> createState() => _RegistrationScreenState();
// }

// class _RegistrationScreenState extends State<RegistrationScreen> {
//   final _formKey = GlobalKey<FormState>();

//   String _name = '';
//   String _email = '';
//   String _phone = '';
//   String _password = '';
//   bool _isLoading = false;
//   String? _errorMessage;

//   Future<void> _register() async {
//     if (!_formKey.currentState!.validate()) return;
//     _formKey.currentState!.save();

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     final auth = Provider.of<AuthService>(context, listen: false);
//     final result = await auth.register(_email.trim(), _password, _name.trim(), _phone.trim());

//     if (!mounted) return;

//     if (result == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Registration successful! Please log in.')),
//       );
//       Navigator.of(context).pop(); // Go back to login screen
//     } else {
//       setState(() {
//         _errorMessage = result;
//       });
//     }

//     setState(() {
//       _isLoading = false;
//     });
//   }

//   Widget _buildTextField({
//     required String label,
//     required bool obscure,
//     required TextInputType keyboardType,
//     required String? Function(String?) validator,
//     required void Function(String?) onSaved,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         style: const TextStyle(color: Colors.amber),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.amber),
//           enabledBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: Colors.amber),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//         obscureText: obscure,
//         keyboardType: keyboardType,
//         validator: validator,
//         onSaved: onSaved,
//         cursorColor: Colors.amber,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text('Register'),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.amber,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Center(
//           child: SingleChildScrollView(
//             child: Card(
//               color: Colors.grey[900],
//               elevation: 6,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildTextField(
//                         label: 'Name',
//                         obscure: false,
//                         keyboardType: TextInputType.name,
//                         validator: (val) => val == null || val.trim().isEmpty ? 'Enter your name' : null,
//                         onSaved: (val) => _name = val!,
//                       ),
//                       _buildTextField(
//                         label: 'Email',
//                         obscure: false,
//                         keyboardType: TextInputType.emailAddress,
//                         validator: (val) {
//                           if (val == null || val.trim().isEmpty) return 'Enter your email';
//                           final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
//                           if (!emailRegex.hasMatch(val.trim())) return 'Enter a valid email';
//                           return null;
//                         },
//                         onSaved: (val) => _email = val!,
//                       ),
//                       _buildTextField(
//                         label: 'Phone Number',
//                         obscure: false,
//                         keyboardType: TextInputType.phone,
//                         validator: (val) => val == null || val.trim().length < 10
//                             ? 'Enter a valid phone number'
//                             : null,
//                         onSaved: (val) => _phone = val!,
//                       ),
//                       _buildTextField(
//                         label: 'Password',
//                         obscure: true,
//                         keyboardType: TextInputType.visiblePassword,
//                         validator: (val) => val == null || val.length < 6
//                             ? 'Password must be at least 6 characters'
//                             : null,
//                         onSaved: (val) => _password = val!,
//                       ),
//                       const SizedBox(height: 20),
//                       if (_errorMessage != null)
//                         Text(
//                           _errorMessage!,
//                           style: const TextStyle(color: Colors.redAccent),
//                           textAlign: TextAlign.center,
//                         ),
//                       const SizedBox(height: 12),
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.amber,
//                             foregroundColor: Colors.black,
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                           ),
//                           onPressed: _isLoading ? null : _register,
//                           child: _isLoading
//                               ? const SizedBox(
//                                   height: 20,
//                                   width: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     color: Colors.black,
//                                   ),
//                                 )
//                               : const Text('Register'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
