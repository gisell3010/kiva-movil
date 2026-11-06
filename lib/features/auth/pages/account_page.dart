import 'package:flutter/material.dart';
import '../../profile/pages/profile_page.dart';
import '../state/auth_controller.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ProfilePage(auth: auth);
}
