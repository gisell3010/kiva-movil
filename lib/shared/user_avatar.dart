import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../features/auth/state/auth_controller.dart';

/// Images are private API resources. Never interpret the storage key as a URL.
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.auth, this.radius = 24});
  final AuthController auth;
  final double radius;
  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _revision;
  Future<Uint8List>? _image;
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      oldWidget.auth.removeListener(_update);
      widget.auth.addListener(_update);
      _revision = null;
      _update();
    }
  }

  void _update() {
    final account = widget.auth.account;
    final revision = account?.profileImage == null
        ? null
        : '${account!.id}:${account.profileImage}';
    if (revision != _revision) {
      _revision = revision;
      _image = revision == null
          ? null
          : widget.auth.repository.api
                .request(
                  'GET',
                  '/users/${account!.id}/profile-image',
                  responseType: ResponseType.bytes,
                )
                .then(
                  (value) => Uint8List.fromList(List<int>.from(value as List)),
                );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Foto de ${widget.auth.account?.name ?? 'perfil'}',
    image: true,
    child: ExcludeSemantics(
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          final initials = Text(
            widget.auth.account?.name.characters.firstOrNull?.toUpperCase() ??
                'K',
            style: TextStyle(fontSize: widget.radius * .8),
          );
          return CircleAvatar(
            radius: widget.radius,
            child:
                _image != null &&
                    snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData
                ? ClipOval(
                    child: Image.memory(
                      snapshot.data!,
                      width: widget.radius * 2,
                      height: widget.radius * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => initials,
                    ),
                  )
                : initials,
          );
        },
      ),
    ),
  );
}
