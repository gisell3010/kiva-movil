# KIVA Mobile

Aplicación Android para organizar viajes en grupo. Permite coordinar participantes, destinos y actividades, llevar el control de gastos y consultar reservas desde el celular. Está desarrollada con Flutter y consume la API de KIVA.

## Funcionalidades

- Registro, inicio de sesión, recuperación de la sesión guardada y cierre de sesión.
- Dashboard, perfil, configuración y gestión de sesiones.
- Grupos, viajes, participantes y permisos según el rol.
- Destinos, itinerarios, actividades y calendario.
- Gastos, repartos, balances, votaciones y reservas.
- Notificaciones, ayuda y reportes de soporte.
- Paneles de soporte, administración y superadministración.
- Imágenes de perfil y destinos, con carga y consulta mediante la API.

Las opciones disponibles dependen del usuario autenticado. El backend valida los permisos y las reglas de cada operación.

## Tecnologías

Flutter y Dart, `flutter_bloc` para la gestión de estado, GoRouter para navegación, Dio para las solicitudes HTTP, Flutter Secure Storage para la sesión e Image Picker para seleccionar imágenes.

El backend utiliza FastAPI y PostgreSQL y se despliega por separado.

## Estructura

```text
lib/
├── bloc/
│   ├── auth/
│   ├── dashboard/
│   └── workspace/
├── models/
├── pages/
├── repositories/
├── services/
├── widgets/
└── main.dart
assets/
├── brand/
└── images/
android/
test/
tool/
```

Las pantallas están en `pages` y los componentes reutilizables en `widgets`. Los modelos representan los datos; los repositorios agrupan las consultas y operaciones, y los servicios gestionan HTTP, almacenamiento, configuración y validaciones.

Los bloques de autenticación, dashboard y módulos de gestión separan eventos, estados y procesamiento. Las pantallas envían eventos y usan `BlocBuilder` para reflejar los estados emitidos. GoRouter controla las rutas y sus restricciones de acceso.

## Requisitos

- Flutter con Dart 3.9 o superior, compatible con las dependencias de `pubspec.yaml`.
- Android SDK y Java 17 o superior compatible con Gradle.
- Un emulador Android o un teléfono con depuración USB para ejecutar la aplicación.
- Conexión HTTPS con el backend.

## Ejecución

Desde la raíz del proyecto:

```sh
flutter pub get
flutter run
```

La API predeterminada es `https://kiva-api.onrender.com/api`. Se puede configurar al ejecutar o compilar:

```sh
flutter run --dart-define=API_BASE_URL=https://kiva-api.onrender.com/api
```

La URL debe usar HTTPS y la ruta base `/api`. Las credenciales del servidor, PostgreSQL y Cloudinary no forman parte de la aplicación.

## Pruebas y compilación

```sh
flutter analyze
flutter test
flutter build apk --debug
```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

La última comprobación completó el análisis sin incidencias, las 57 pruebas automatizadas y la compilación debug de Android. Las pruebas incluyen sesión, validaciones, navegación, permisos del menú de cuenta y adaptación de la interfaz. No sustituyen la validación en un dispositivo físico ni las pruebas integrales con cuentas reales de todos los roles.

La configuración actual de release utiliza la firma de depuración. Para distribuir la aplicación se debe configurar una firma de producción y mantener sus claves fuera del repositorio.

## Seguridad

La sesión de renovación se guarda con Flutter Secure Storage y el token de acceso permanece en memoria. Las imágenes se gestionan a través del backend. Los archivos de entorno, claves, configuraciones locales y artefactos de compilación están excluidos mediante `.gitignore`.

## Referencias

- [Documentación de Flutter](https://docs.flutter.dev/)
- [BLoC para Flutter](https://bloclibrary.dev/)
- [Taller de Flutter: patrón BLoC](https://diln20.github.io/tallerFlutterDesarrollo/#bloc)
