import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/services/validators.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/repositories/help/support_repository.dart';

const supportCategories = {
  'ACCESS': 'Acceso',
  'ACCOUNT': 'Cuenta',
  'TRIP': 'Viaje',
  'EXPENSE': 'Gastos',
  'VOTING': 'Votaciones',
  'RESERVATION': 'Reservas',
  'TECHNICAL': 'Problema técnico',
  'OTHER': 'Otro',
};
String supportStatus(Object? status) => switch (status) {
  'OPEN' => 'Abierto',
  'IN_REVIEW' => 'En revisión',
  'ESCALATED' => 'En revisión administrativa',
  'RESOLVED' => 'Resuelto',
  'CLOSED' => 'Cerrado',
  _ => 'En seguimiento',
};

class SupportPage extends StatelessWidget {
  const SupportPage({super.key, required this.auth});
  final AuthBloc auth;
  @override
  Widget build(BuildContext context) {
    final public = auth.phase != AuthPhase.signedIn;
    final repository = SupportRepository(auth.repository.api);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y soporte'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(public ? '/login' : '/perfil');
            }
          },
        ),
      ),
      body: PageBody(
        children: [
          const Text('¿Cómo podemos ayudarte?'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Reportar un problema'),
              subtitle: Text(
                public
                    ? 'Recupera el acceso o solicita ayuda.'
                    : 'Cuéntanos qué ocurrió.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SupportForm(repository: repository, public: public),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(public ? 'Consultar un reporte' : 'Mis reportes'),
              subtitle: const Text(
                'Consulta respuestas y continúa la conversación.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => public
                      ? SupportLookup(repository: repository)
                      : SupportReports(repository: repository),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SupportForm extends StatefulWidget {
  const SupportForm({
    super.key,
    required this.repository,
    required this.public,
  });
  final SupportRepository repository;
  final bool public;
  @override
  State<SupportForm> createState() => _SupportFormState();
}

class _SupportFormState extends State<SupportForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  int? _trip;
  Future<List<Json>>? _trips;
  bool _busy = false;
  String? _error;
  Json? _receipt;
  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.repository.create({
        'category': _category!,
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        if (widget.public) 'contact_email': _email.text.trim().toLowerCase(),
        if (!widget.public && _trip != null) 'trip_id': _trip,
      }, public: widget.public);
      if (mounted) setState(() => _receipt = receipt);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reportar un problema')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _receipt != null
                ? _confirmation()
                : Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.public) ...[
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            validator: Validators.email,
                            maxLength: 150,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Correo de contacto',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          hint: const Text('Selecciona una categoría'),
                          validator: (value) => value == null
                              ? 'Selecciona una categoría.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                          items: [
                            for (final item in supportCategories.entries)
                              if (!widget.public ||
                                  const [
                                    'ACCESS',
                                    'ACCOUNT',
                                    'TECHNICAL',
                                    'OTHER',
                                  ].contains(item.key))
                                DropdownMenuItem(
                                  value: item.key,
                                  child: Text(item.value),
                                ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _category = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _subject,
                          enabled: !_busy,
                          maxLength: 150,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredText(v, min: 5, max: 150),
                          decoration: const InputDecoration(
                            labelText: 'Asunto',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          enabled: !_busy,
                          maxLength: 1000,
                          minLines: 4,
                          maxLines: 7,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) =>
                              Validators.requiredText(v, min: 10, max: 1000),
                          decoration: const InputDecoration(
                            labelText: '¿Qué ocurrió?',
                            helperText:
                                'No incluyas contraseñas ni datos de pago.',
                          ),
                        ),
                        if (!widget.public)
                          ExpansionTile(
                            title: const Text('Relacionar con un viaje'),
                            onExpansionChanged: (open) {
                              if (open && _trips == null) {
                                setState(
                                  () => _trips = widget.repository.trips(),
                                );
                              }
                            },
                            children: [
                              FutureBuilder<List<Json>>(
                                future: _trips,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Notice(
                                      friendlyError(snapshot.error!),
                                      onRetry: () => setState(
                                        () =>
                                            _trips = widget.repository.trips(),
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const LinearProgressIndicator();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _trip,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Viaje (opcional)',
                                      ),
                                      items: [
                                        const DropdownMenuItem<int>(
                                          child: Text('Sin viaje asociado'),
                                        ),
                                        for (final trip in snapshot.data!)
                                          DropdownMenuItem(
                                            value: trip['id'] as int,
                                            child: Text(
                                              trip['name'].toString(),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _busy
                                          ? null
                                          : (v) => setState(() => _trip = v),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_error != null) Notice(_error!),
                        if (_busy)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Enviando reporte',
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: Text(_busy ? 'Enviando…' : 'Enviar reporte'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
  Widget _confirmation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.check_circle_outline, size: 48),
      const SizedBox(height: 16),
      Text('Reporte enviado', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('Tu solicitud quedó registrada correctamente.'),
      if (widget.public) ...[
        const SizedBox(height: 16),
        const Text('Guarda este código para consultar las respuestas.'),
        const SizedBox(height: 8),
        SelectableText(_receipt!['tracking_token'].toString()),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: _receipt!['tracking_token'].toString()),
            );
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Datos copiados.')));
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copiar datos'),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SupportConversation(
              repository: widget.repository,
              reportId: _receipt!['id'] as int,
              token: _receipt!['tracking_token'] as String?,
            ),
          ),
        ),
        child: const Text('Ver conversación'),
      ),
    ],
  );
  @override
  void dispose() {
    _email.dispose();
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }
}

class SupportLookup extends StatefulWidget {
  const SupportLookup({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<SupportLookup> createState() => _SupportLookupState();
}

class _SupportLookupState extends State<SupportLookup> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _token = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Consultar un reporte')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _id,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.reportId,
              decoration: const InputDecoration(
                labelText: 'Referencia del reporte',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _token,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 100,
              validator: (v) => Validators.requiredText(v, min: 32, max: 100),
              decoration: const InputDecoration(
                labelText: 'Código de seguimiento',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SupportConversation(
                      repository: widget.repository,
                      reportId: int.parse(_id.text),
                      token: _token.text.trim(),
                    ),
                  ),
                );
              },
              child: const Text('Consultar'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _id.dispose();
    _token.dispose();
    super.dispose();
  }
}

class SupportReports extends StatefulWidget {
  const SupportReports({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<SupportReports> createState() => _SupportReportsState();
}

class _SupportReportsState extends State<SupportReports> {
  late Future<List<Json>> _reports = widget.repository.reports();
  Future<void> _refresh() async {
    final next = widget.repository.reports();
    setState(() => _reports = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis reportes'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.pop(context);
          } else {
            context.go('/perfil');
          }
        },
      ),
    ),
    body: FutureBuilder<List<Json>>(
      future: _reports,
      builder: (context, snapshot) => PageBody(
        onRefresh: _refresh,
        children: [
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            Notice(friendlyError(snapshot.error!), onRetry: _refresh),
          if (snapshot.hasData && snapshot.data!.isEmpty)
            const Notice('Aún no has enviado reportes.'),
          for (final report in snapshot.data ?? <Json>[])
            Card(
              child: ListTile(
                title: Text(report['subject'].toString()),
                subtitle: Text(supportStatus(report['status'])),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SupportConversation(
                        repository: widget.repository,
                        reportId: report['id'] as int,
                      ),
                    ),
                  );
                  if (mounted) _refresh();
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class SupportConversation extends StatefulWidget {
  const SupportConversation({
    super.key,
    required this.repository,
    required this.reportId,
    this.token,
    this.staff = false,
    this.staffId,
    this.admin = false,
  });
  final SupportRepository repository;
  final int reportId;
  final String? token;
  final bool staff;
  final int? staffId;
  final bool admin;
  @override
  State<SupportConversation> createState() => _SupportConversationState();
}

class _SupportConversationState extends State<SupportConversation> {
  final _reply = TextEditingController();
  final _form = GlobalKey<FormState>();
  Json? _report;
  List<Json> _messages = [];
  bool _loading = true;
  bool _busy = false;
  bool _internal = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await widget.repository.detail(
        widget.reportId,
        token: widget.token,
        staff: widget.staff,
      );
      final messages = await widget.repository.messages(
        widget.reportId,
        token: widget.token,
        staff: widget.staff,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _messages = messages;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reply(
        widget.reportId,
        _reply.text,
        token: widget.token,
        staff: widget.staff,
        internal: _internal,
      );
      if (!mounted) return;
      _reply.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mensaje enviado.')));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _report?['status'];
    final canReply =
        _report != null &&
        status != 'CLOSED' &&
        (!widget.staff ||
            (status != 'RESOLVED' &&
                (status != 'ESCALATED' || widget.admin) &&
                (_report!['assigned_to_user_id'] == widget.staffId)));
    return Scaffold(
      appBar: AppBar(title: const Text('Conversación de soporte')),
      body: PageBody(
        onRefresh: _load,
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Notice(_error!, onRetry: _load),
          if (_report != null) ...[
            Text(
              _report!['subject'].toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              supportStatus(status),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(_report!['description'].toString()),
            const SizedBox(height: 16),
            for (final message in _messages)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${message['author_label']}${message['is_internal'] == true ? ' · Nota interna' : ''}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(message['body'].toString()),
                    ],
                  ),
                ),
              ),
            if (_messages.isEmpty && _report!['response'] != null)
              Notice(_report!['response'].toString()),
            if (canReply)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status == 'RESOLVED')
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Al responder, volveremos a revisar tu reporte.',
                        ),
                      ),
                    if (widget.staff)
                      SwitchListTile(
                        title: const Text('Nota interna'),
                        value: _internal,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _internal = v),
                      ),
                    TextFormField(
                      controller: _reply,
                      enabled: !_busy,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      validator: (v) =>
                          Validators.requiredText(v, min: 2, max: 1000),
                      decoration: InputDecoration(
                        labelText: _internal
                            ? 'Nota para el equipo'
                            : 'Tu mensaje',
                      ),
                    ),
                    if (_busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Enviando mensaje',
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _send,
                      child: const Text('Enviar mensaje'),
                    ),
                  ],
                ),
              )
            else if (status == 'CLOSED')
              const Notice(
                'Este reporte está cerrado. Puedes crear uno nuevo si necesitas ayuda.',
              ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }
}
