import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wear_plus/wear_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// MODELO DE DATOS Y UTILIDADES DE COLOR
// -----------------------------------------------------------------------------
class Note {
  String text;
  String colorHex;

  Note({required this.text, required this.colorHex});

  Color get color => _colorFromHex(colorHex);

  Map<String, dynamic> toJson() => {
        'text': text,
        'colorHex': colorHex,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        text: json['text'] as String,
        colorHex: json['colorHex'] as String,
      );
}

// Helper para convertir un string hexadecimal a un color
Color _colorFromHex(String hex) {
  final hexCode = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}

// Paleta de colores para las notas
final List<String> noteColorPalette = [
  '#A3B18A', // Verde suave (default)
  '#84A98C', // Verde medio
  '#6B9080', // Verde azulado
  '#F4A261', // Naranja arena
];

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
        AndroidInitializationSettings('ic_notification');

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
// SERVICIO DE MENSAJERÍA (PARA SNACKBARS)
// -----------------------------------------------------------------------------
// Clave global para acceder al ScaffoldMessenger desde cualquier parte de la app.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Gestiona la visualización de SnackBars para feedback en la web.
class MessengerService {
  void showSnackbar(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }
}

// -----------------------------------------------------------------------------
// PROVEEDORES DE ESTADO (usando Provider)
// -----------------------------------------------------------------------------

// Gestiona el estado de la lista de notas.
class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> get notes => _notes;
  static const _notesKey = 'notes_key';

  NoteProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList(_notesKey) ?? [];
    _notes = notesJson
        .map((jsonString) => Note.fromJson(json.decode(jsonString)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _notes.map((note) => json.encode(note.toJson())).toList();
    await prefs.setStringList(_notesKey, notesJson);
  }

  void addNote(String note) {
    final newNote = Note(text: note, colorHex: noteColorPalette.first);
    _notes.add(newNote);
    _saveNotes();
    notifyListeners();
    if (kIsWeb) {
      MessengerService().showSnackbar('Nota guardada');
    } else {
      NotificationService().showNotification('Nota Guardada', 'Tu nota ha sido añadida correctamente.');
    }
  }

  void deleteNote(int index) {
    if (index >= 0 && index < _notes.length) {
      final deletedNoteText = _notes[index].text;
      _notes.removeAt(index);
      _saveNotes();
      notifyListeners();
      if (kIsWeb) {
        MessengerService().showSnackbar('Nota eliminada: "${deletedNoteText.substring(0, (deletedNoteText.length > 15) ? 15 : deletedNoteText.length)}..."');
      } else {
        NotificationService().showNotification('Nota Eliminada', 'La nota ha sido borrada.');
      }
    }
  }

  void updateNoteColor(int index, String newColorHex) {
    if (index >= 0 && index < _notes.length) {
      _notes[index].colorHex = newColorHex;
      _saveNotes();
      notifyListeners();
    }
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
        scaffoldMessengerKey: scaffoldMessengerKey, // Asignamos la clave global
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
      fontFamily: 'Poppins',
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
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startListening(BuildContext context) async {
    // 1. Solicitar permiso de micrófono
    PermissionStatus status = await Permission.microphone.request();

    // 2. Comprobar el estado del permiso
    if (!status.isGranted) {
      // Si el permiso fue denegado permanentemente, guiar al usuario a los ajustes.
      if (status.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permiso Necesario'),
            content: const Text(
                'Para usar el dictado por voz, habilita el permiso de micrófono en los ajustes de la aplicación.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings(); // Abre los ajustes de la app
                  Navigator.of(context).pop();
                },
                child: const Text('Abrir Ajustes'),
              ),
            ],
          ),
        );
      } else {
        // Si solo fue denegado esta vez, mostrar una notificación.
        NotificationService().showNotification(
            "Permiso denegado", "Se necesita acceso al micrófono para dictar notas.");
      }
      return; // Detener la ejecución si no hay permiso
    }

    // 3. Si el permiso está concedido, verificar si el servicio está disponible
    bool available = false;
    try {
      available = await _speech.initialize();
    } catch (e) {
      // La excepción PlatformException será capturada aquí.
      // 'available' permanecerá como 'false'.
    }
    if (!available) {
      NotificationService().showNotification("Error", "Reconocimiento de voz no disponible.");
      return;
    }
    // Comprueba si el widget sigue montado después de la operación asíncrona.
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _DictationDialog(speech: _speech),
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
// WIDGET DE DIÁLOGO PARA DICTADO
// -----------------------------------------------------------------------------
class _DictationDialog extends StatefulWidget {
  final SpeechToText speech;
  const _DictationDialog({required this.speech});

  @override
  State<_DictationDialog> createState() => _DictationDialogState();
}

class _DictationDialogState extends State<_DictationDialog> {
  String _recognizedWords = "";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    setState(() => _isListening = true);

    widget.speech.statusListener = (status) {
      if (status == 'notListening' || status == 'done') {
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
    };

    widget.speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _recognizedWords = result.recognizedWords);
        }
      },
    );
  }

  void _stopListening() {
    widget.speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFDAD7CD),
      title: Text('Dictando nota...', style: Theme.of(context).textTheme.headlineSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(_recognizedWords.isEmpty ? 'Escuchando...' : _recognizedWords, textAlign: TextAlign.center),
        ],
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar', style: TextStyle(color: Colors.red)), onPressed: () {
          _stopListening();
          Navigator.of(context).pop();
        }),
        TextButton(child: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.primary)), onPressed: () {
          if (_recognizedWords.isNotEmpty) {
            Provider.of<NoteProvider>(context, listen: false).addNote(_recognizedWords);
          }
          _stopListening();
          Navigator.of(context).pop();
        }),
      ],
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
      appBar: AppBar(
        title: Text('Mis notas', style: theme.textTheme.headlineSmall),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Consumer<NoteProvider>(
          builder: (context, noteProvider, child) {
            if (noteProvider.notes.isEmpty) {
              return const Center(child: Text('No hay notas guardadas.'));
            }
            return ListView.builder( // CAMBIO: Usar ListView.builder para eficiencia
              itemCount: noteProvider.notes.length,
              itemBuilder: (context, index) {
                final note = noteProvider.notes[index];
                return Card(
                  color: note.color.withOpacity(0.8),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteDetailScreen(
                            noteIndex: index,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text(
                        note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => noteProvider.deleteNote(index),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA DE DETALLE DE NOTA
// -----------------------------------------------------------------------------
class NoteDetailScreen extends StatelessWidget {
  final int noteIndex;

  const NoteDetailScreen({
    super.key,
    required this.noteIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Usamos un Consumer para que la pantalla se reconstruya si cambia el color de la nota
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        // Asegurarse de que el índice es válido
        if (noteIndex >= noteProvider.notes.length) {
          // Si la nota fue eliminada mientras esta pantalla estaba abierta, la cerramos.
          // Usamos un post-frame callback para evitar errores de build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final note = noteProvider.notes[noteIndex];

        return Scaffold(
          appBar: AppBar(
            title: Text('Detalle', style: theme.textTheme.headlineSmall),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      note.text,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Paleta de colores
                _buildColorPalette(context),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    // Usar Provider para borrar la nota y luego cerrar la pantalla
                    Provider.of<NoteProvider>(context, listen: false).deleteNote(noteIndex);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete, color: theme.colorScheme.error),
                  label: Text(
                    'Eliminar Nota',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPalette(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final currentNoteColor = noteProvider.notes[noteIndex].colorHex;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: noteColorPalette.map((colorHex) {
        final color = _colorFromHex(colorHex);
        final isSelected = colorHex == currentNoteColor;

        return GestureDetector(
          onTap: () {
            noteProvider.updateNoteColor(noteIndex, colorHex);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                  : Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
          ),
        );
      }).toList(),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
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
              )
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
      appBar: AppBar(
        title: Text('Configuración', style: theme.textTheme.headlineSmall),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSettingItem(
                  context: context,
                  icon: Icons.wifi,
                  label: 'Wi-Fi',
                  isActive: settings.isWifiEnabled,
                  onTap: () => settings.toggleWifi(),
                ),
                const SizedBox(height: 10),
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