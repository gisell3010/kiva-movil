
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key, this.profile = false, this.section});

  final bool profile;
  final String? section;

  @override
  Widget build(BuildContext context) {
    const routes = <String>['/dashboard', '/grupos', '/viajes', '/perfil'];

    // Detecta si la aplicación está en modo oscuro.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // En modo claro, el ícono seleccionado será blanco.
    // En modo oscuro, conserva el color definido por el tema.
    final Color? selectedColor = isDark ? null : Colors.white;

    return NavigationBar(
      selectedIndex: profile
          ? routes.length - 1
          : section == 'groups'
              ? 1
              : section == 'trips'
                  ? 2
                  : 0,
      onDestinationSelected: (index) => context.go(routes[index]),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(
            Icons.home,
            color: selectedColor,
          ),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: isDark
              ? null
              : const Icon(
                  Icons.groups_outlined,
                  color: Colors.white,
                ),
          label: 'Grupos',
        ),
        NavigationDestination(
          icon: const Icon(Icons.flight_takeoff_outlined),
          selectedIcon: isDark
              ? null
              : const Icon(
                  Icons.flight_takeoff_outlined,
                  color: Colors.white,
                ),
          label: 'Viajes',
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: Icon(
            Icons.person,
            color: selectedColor,
          ),
          label: 'Perfil',
        ),
      ],
    );
  }
}