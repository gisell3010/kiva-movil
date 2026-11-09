import 'package:flutter/material.dart';
import 'package:kiva_mobile_final/pages/profile/profile_page.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.auth});
  final AuthBloc auth;
  @override
  Widget build(BuildContext context) => ProfilePage(auth: auth);
}
