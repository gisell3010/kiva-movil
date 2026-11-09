import 'package:flutter/material.dart';
import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';
import 'package:kiva_mobile_final/repositories/help/support_repository.dart';
import 'support_page.dart';

class PublicHelpPage extends StatelessWidget {
  const PublicHelpPage({super.key, required this.api});
  final KivaApi api;
  @override
  Widget build(BuildContext context) =>
      SupportForm(repository: SupportRepository(api.client), public: true);
}
