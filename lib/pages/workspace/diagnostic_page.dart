import 'package:flutter/material.dart';

import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';
import 'package:kiva_mobile_final/widgets/workspace_drawer.dart';

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({
    super.key,
    required this.auth,
    required this.api,
    this.userId,
  });
  final AuthBloc auth;
  final KivaApi api;
  final int? userId;
  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  String _section = 'participants';
  bool _loading = false;
  bool _tripsLoading = true;
  String? _error;
  int? _tripId;
  List<KivaMap> _groups = <KivaMap>[];
  List<KivaMap> _trips = <KivaMap>[];
  List<KivaMap> _items = <KivaMap>[];

  int? _id(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: WorkspaceDrawer(account: widget.auth.account),
    appBar: AppBar(
      title: const Text('Diagnóstico de viaje'),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Abrir navegación',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    ),
    body: PageBody(
      children: [
        Text(
          widget.userId == null
              ? 'Consulta información autorizada del viaje seleccionado.'
              : 'Consulta la información autorizada de la cuenta seleccionada.',
        ),
        if (widget.userId != null) ...[
          Text(
            'Grupos de la cuenta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!_tripsLoading && _groups.isEmpty)
            const Notice('La cuenta no pertenece a ningún grupo.'),
          for (final group in _groups)
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(group['name']?.toString() ?? 'Grupo'),
                subtitle: Text(
                  group['description']?.toString() ?? 'Información disponible',
                ),
              ),
            ),
        ],
        DropdownButtonFormField<int>(
          initialValue: _trips.any((trip) => _id(trip['id']) == _tripId)
              ? _tripId
              : null,
          decoration: const InputDecoration(
            labelText: 'Viaje',
            prefixIcon: Icon(Icons.flight_takeoff_outlined),
          ),
          items: [
            for (final trip in _trips)
              if (_id(trip['id']) != null)
                DropdownMenuItem<int>(
                  value: _id(trip['id']),
                  child: Text(trip['name']?.toString() ?? 'Viaje'),
                ),
          ],
          onChanged: _tripsLoading
              ? null
              : (value) => setState(() => _tripId = value),
        ),
        if (!_tripsLoading && _trips.isEmpty)
          const Notice('No tienes viajes disponibles para consultar.'),
        DropdownButtonFormField<String>(
          initialValue: _section,
          decoration: const InputDecoration(labelText: 'Sección'),
          items: const [
            DropdownMenuItem(
              value: 'participants',
              child: Text('Participantes'),
            ),
            DropdownMenuItem(value: 'destinations', child: Text('Destinos')),
            DropdownMenuItem(value: 'activities', child: Text('Actividades')),
            DropdownMenuItem(value: 'expenses', child: Text('Gastos')),
            DropdownMenuItem(value: 'splits', child: Text('Repartos')),
            DropdownMenuItem(value: 'polls', child: Text('Votaciones')),
            DropdownMenuItem(value: 'options', child: Text('Opciones')),
            DropdownMenuItem(value: 'reservations', child: Text('Reservas')),
          ],
          onChanged: (value) =>
              setState(() => _section = value ?? 'participants'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.search),
          label: const Text('Consultar'),
        ),
        if (_error != null) Notice(_error!),
        if (_loading) const LinearProgressIndicator(),
        for (final item in _items)
          Card(
            child: ListTile(
              title: Text(item['title']?.toString() ?? 'Registro'),
              subtitle: Text(item['detail']?.toString() ?? ''),
            ),
          ),
      ],
    ),
  );

  Future<void> _loadTrips() async {
    try {
      List<KivaMap> groups = <KivaMap>[];
      final List<KivaMap> trips;
      if (widget.userId == null) {
        trips = await widget.api.trips();
      } else {
        groups = await widget.api.supportUserGroups(widget.userId!);
        trips = await widget.api.supportUserTrips(widget.userId!);
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _trips = trips;
        _tripId = trips.isEmpty ? null : _id(trips.first['id']);
        _tripsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tripsLoading = false;
        _error = friendlyError(error);
      });
    }
  }

  Future<void> _load() async {
    final tripId = _tripId;
    if (tripId == null) {
      setState(() => _error = 'Selecciona un viaje válido.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await widget.api.diagnostic(tripId, _section);
    } catch (error) {
      _error = friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
