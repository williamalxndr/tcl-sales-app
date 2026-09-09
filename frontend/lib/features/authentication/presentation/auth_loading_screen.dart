import 'package:flutter/material.dart';

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'Memeriksa sesi Anda',
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
