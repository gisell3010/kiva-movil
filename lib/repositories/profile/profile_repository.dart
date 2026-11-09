import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/errors.dart';

class ProfileRepository {
  ProfileRepository(this.client);
  final ApiClient client;
  static const maxImageBytes = 5 * 1024 * 1024;
  static Future<String> validateImage(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const AppFailure('Elige una foto de hasta 5 MB.');
    }
    final jpeg =
        bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length > 8 &&
        bytes[0] == 137 &&
        String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG';
    final webp =
        bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpeg && !png && !webp) {
      throw const AppFailure('Elige una foto JPEG, PNG o WebP sin animación.');
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 20000000) {
        throw const AppFailure('Elige una foto de hasta 20 megapíxeles.');
      }
      codec = await descriptor.instantiateCodec(targetWidth: 512);
      if (codec.frameCount > 1) {
        throw const AppFailure('Elige una foto sin animación.');
      }
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('No pudimos abrir la foto. Elige otra imagen.');
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
    return jpeg
        ? 'image/jpeg'
        : png
        ? 'image/png'
        : 'image/webp';
  }

  Future<Json> update(String name, String username) async =>
      Map<String, dynamic>.from(
        await client.request(
              'PATCH',
              '/users/me',
              data: {
                'full_name': name.trim(),
                'username': username.trim().toLowerCase(),
              },
            )
            as Map,
      );
  Future<Json> upload(Uint8List bytes) async {
    final mime = await validateImage(bytes);
    final extension = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'profile.$extension',
        contentType: DioMediaType.parse(mime),
      ),
    });
    return Map<String, dynamic>.from(
      await client.request('PUT', '/users/me/profile-image', data: form) as Map,
    );
  }

  Future<void> deleteImage() async {
    await client.request('DELETE', '/users/me/profile-image');
  }

  Future<List<Json>> sessions() async =>
      (await client.request('GET', '/auth/sessions') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> changeEmail(String email, String password) async {
    await client.request(
      'PUT',
      '/users/me/email',
      data: {'email': email.trim().toLowerCase(), 'current_password': password},
    );
  }

  Future<void> changePassword(String current, String next) async {
    await client.request(
      'PUT',
      '/users/me/password',
      data: {'current_password': current, 'new_password': next},
    );
  }

  Future<void> revoke(int id) async {
    await client.request('DELETE', '/auth/sessions/$id');
  }

  Future<void> logoutAll() async {
    await client.request('POST', '/auth/logout-all', data: <String, dynamic>{});
  }
}
