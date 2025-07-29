import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// PASO 1: Agrega estas dependencias a tu archivo `pubspec.yaml`
// -----------------------------------------------------------------------------
// dependencies:
//   flutter:
//     sdk: flutter
//   wear_plus: ^2.0.1 // <--- CAMBIO: Usar wear_plus en lugar de wear
//   speech_to_text: ^6.6.0
//   flutter_local_notifications: ^17.1.2
//   provider: ^6.1.2
//   intl: ^0.19.0
//   shared_preferences: ^2.2.3 // <--- AÑADIR PARA PERSISTENCIA
//   permission_handler: ^11.3.1 // <--- AÑADIR PARA PERMISOS
//
// Y no olvides agregar los permisos para el micrófono en:
// android/app/src/main/AndroidManifest.xml
// <uses-permission android:name="android.permission.RECORD_AUDIO" />
// <uses-permission android:name="android.permission.BLUETOOTH" />
// <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
// <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// SERVICIO DE NOTIFICACIONES
// -----------------------------------------------------------------------------
// Gestiona el envío de notificaciones locales en el dispositivo.
class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('main_channel', 'Main Channel',
            channelDescription: 'Canal principal para notificaciones de la app',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics);
  }
}


// -----------------------------------------------------------------------------
// PROVEEDORES DE ESTADO (usando Provider)
// -----------------------------------------------------------------------------

// Gestiona el estado de la lista de notas.
class NoteProvider with ChangeNotifier {
  List<String> _notes = [];
  List<String> get notes => _notes;
  static const _notesKey = 'notes_key';

  NoteProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    _notes = prefs.getStringList(_notesKey) ?? [];
    notifyListeners();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notesKey, _notes);
  }

  void addNote(String note) {
    _notes.add(note);
    _saveNotes();
    notifyListeners();
    NotificationService().showNotification('Nota Guardada', 'Tu nota ha sido añadida correctamente.');
  }

  void deleteNote(int index) {
    _notes.removeAt(index);
    _saveNotes();
    notifyListeners();
    NotificationService().showNotification('Nota Eliminada', 'La nota ha sido borrada.');
  }
}

// Simula y gestiona el estado de las conexiones.
class SettingsProvider with ChangeNotifier {
  bool _isWifiEnabled = true;
  bool _isBluetoothEnabled = true;

  bool get isWifiEnabled => _isWifiEnabled;
  bool get isBluetoothEnabled => _isBluetoothEnabled;

  void toggleWifi() {
    _isWifiEnabled = !_isWifiEnabled;
    notifyListeners();
    final status = _isWifiEnabled ? "conectado" : "desconectado";
    NotificationService().showNotification('Wi-Fi', 'Wi-Fi $status.');
  }

  void toggleBluetooth() {
    _isBluetoothEnabled = !_isBluetoothEnabled;
    notifyListeners();
    final status = _isBluetoothEnabled ? "conectado" : "desconectado";
    NotificationService().showNotification('Bluetooth', 'Bluetooth $status.');
  }
}


// -----------------------------------------------------------------------------
// PUNTO DE ENTRADA PRINCIPAL DE LA APP
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init(); // Inicializa el servicio de notificaciones
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos MultiProvider para proveer los estados a toda la app.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Wear OS Notes',
        theme: _buildAppTheme(),
        home: const WatchScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  // Define el tema de la aplicación con la paleta de colores especificada.
  ThemeData _buildAppTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF3A5A40),
      scaffoldBackgroundColor: const Color(0xFFDAD7CD),
      colorScheme: const ColorScheme(
        primary: Color(0xFF588157), // Botones principales
        secondary: Color(0xFFA3B18A), // Elementos secundarios
        surface: Color(0xFFDAD7CD), // Superficies, fondo claro
        background: Color(0xFFDAD7CD), // Fondo general
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Color(0xFF344E41), // Texto sobre superficies claras
        onBackground: Color(0xFF344E41),
        onError: Colors.white,
        brightness: Brightness.light,
        primaryContainer: Color(0xFF3A5A40), // Encabezados o iconos
        surfaceVariant: Color(0xFF344E41), // AppBar, fondo oscuro
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Color(0xFF3A5A40), fontWeight: FontWeight.bold, fontSize: 18),
        bodyMedium: TextStyle(color: Color(0xFF344E41)),
        bodyLarge: TextStyle(color: Color(0xFF344E41), fontSize: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF588157),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(15),
        ),
      ),
    );
  }
}

// Widget principal que detecta la forma del reloj (redondo o cuadrado).
class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return AmbientMode(
          builder: (context, mode, child) {
            return HomeScreen(mode: mode);
          },
        );
      },
    );
  }
}


// -----------------------------------------------------------------------------
// PANTALLA PRINCIPAL (HOME)
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final WearMode mode;
  const HomeScreen({super.key, required this.mode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  late DateTime _now;
  final SpeechToText _speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
    _initSpeech();
  }
  
  void _initSpeech() async {
    await _speech.initialize();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startListening(BuildContext context) async {
    // 1. Solicitar permiso de micrófono
    var status = await Permission.microphone.request();

    // 2. Comprobar el estado del permiso
    if (status != PermissionStatus.granted) {
      NotificationService().showNotification(
          "Permiso denegado", "Se necesita acceso al micrófono para dictar notas.");
      return;
    }

    // 3. Verificar si el servicio está disponible después de conceder el permiso
    bool available = await _speech.initialize();
    if (!available) {
      NotificationService().showNotification("Error", "Reconocimiento de voz no disponible.");
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        String recognizedWords = "";
        bool isListening = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!isListening) {
  isListening = true;

  // Set status listener
  _speech.statusListener = (status) {
    if (status == 'notListening') {
      setDialogState(() {
        isListening = false;
      });
    }
  };

  _speech.listen(
    onResult: (result) {
      setDialogState(() {
        recognizedWords = result.recognizedWords;
      });
    },
  );
}

            return AlertDialog(
              backgroundColor: const Color(0xFFDAD7CD),
              title: Text('Dictando nota...', style: Theme.of(context).textTheme.headlineSmall),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_off,
                    color: Theme.of(context).colorScheme.primary, 
                    size: 40),
                  const SizedBox(height: 16),
                  Text(recognizedWords.isEmpty ? 'Escuchando...' : recognizedWords, textAlign: TextAlign.center),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    _speech.stop();
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  onPressed: () {
                    if (recognizedWords.isNotEmpty) {
                      Provider.of<NoteProvider>(context, listen: false).addNote(recognizedWords);
                    }
                    _speech.stop();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAmbient = widget.mode == WearMode.ambient;
    final theme = Theme.of(context);
    final timeStyle = TextStyle(
      color: isAmbient ? Colors.white : theme.colorScheme.primaryContainer,
      fontSize: 40,
      fontWeight: FontWeight.bold,
    );
    final dateStyle = TextStyle(
      color: isAmbient ? Colors.white : theme.colorScheme.secondary,
      fontSize: 16,
    );

    return Scaffold(
      backgroundColor: isAmbient ? Colors.black : theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Reloj y Fecha
            Text(DateFormat('HH:mm').format(_now), style: timeStyle),
            Text(DateFormat('EEE, d MMM').format(_now), style: dateStyle),
            const SizedBox(height: 15),

            if (!isAmbient)
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _startListening(context),
                    child: const Icon(Icons.mic),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TextNoteScreen()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                    child: const Icon(Icons.edit),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (!isAmbient)
              // Botones de navegación
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.list_alt, color: theme.colorScheme.primaryContainer),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen())),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: theme.colorScheme.primaryContainer),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// PANTALLA DE LISTA DE NOTAS (CON SWIPE-TO-DISMISS AUTOMÁTICO)
// -----------------------------------------------------------------------------
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //
    // CAMBIO: Se eliminó el widget `DismissiblePage`.
    // El gesto de deslizar para descartar es manejado automáticamente por `wear_plus`.
    //
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 25.0, bottom: 10.0),
              child: Text('Notas', style: theme.textTheme.headlineSmall),
            ),
            Expanded(
              child: Consumer<NoteProvider>(
                builder: (context, noteProvider, child) {
                  if (noteProvider.notes.isEmpty) {
                    return const Center(child: Text('No hay notas guardadas.'));
                  }
                  return ListView.builder(
                    itemCount: noteProvider.notes.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: theme.colorScheme.secondary.withOpacity(0.5),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(
                            noteProvider.notes[index],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => noteProvider.deleteNote(index),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA PARA AÑADIR NOTA POR TEXTO
// -----------------------------------------------------------------------------
class TextNoteScreen extends StatefulWidget {
  const TextNoteScreen({super.key});

  @override
  State<TextNoteScreen> createState() => _TextNoteScreenState();
}

class _TextNoteScreenState extends State<TextNoteScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Nueva Nota', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Escribe tu nota...',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    Provider.of<NoteProvider>(context, listen: false)
                        .addNote(_controller.text);
                    Navigator.pop(context);
                  } else {
                    NotificationService().showNotification(
                        'Error', 'La nota no puede estar vacía.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA DE CONFIGURACIÓN (CON SWIPE-TO-DISMISS AUTOMÁTICO)
// -----------------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //
    // CAMBIO: Se eliminó el widget `DismissiblePage`.
    // El gesto de deslizar para descartar es manejado automáticamente por `wear_plus`.
    //
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 25.0, bottom: 20.0),
                  child: Text(
                    'Configuración',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildSettingItem(
                  context: context,
                  icon: Icons.wifi,
                  label: 'Wi-Fi',
                  isActive: settings.isWifiEnabled,
                  onTap: () => settings.toggleWifi(),
                ),
                const SizedBox(height: 20),
                _buildSettingItem(
                  context: context,
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  isActive: settings.isBluetoothEnabled,
                  onTap: () => settings.toggleBluetooth(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primaryContainer, size: 28),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.bodyLarge),
              ],
            ),
            Icon(
              isActive ? Icons.toggle_on : Icons.toggle_off,
              color: isActive ? theme.colorScheme.primary : Colors.grey,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}