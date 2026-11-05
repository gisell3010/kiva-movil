import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key, this.profile = false, this.section});
  final bool profile;
  final String? section;
  @override
  Widget build(BuildContext context) {
    const routes = <String>['/dashboard', '/perfil'];
    return NavigationBar(
      selectedIndex: profile
          ? routes.length - 1
          : section == 'groups'
          ? 1
          : section == 'trips'
          ? 2
          : 0,
      onDestinationSelected: (index) => context.go(routes[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
