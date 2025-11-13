import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/scheduler.dart'; // Ticker
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const PianoApp());

class PianoApp extends StatelessWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
      ),
      builder: (context, child) => FocusScope(
        canRequestFocus: false,
        skipTraversal: true,
        child: child!,
      ),
      home: const Scaffold(body: SafeArea(child: PianoGame())),
    );
  }
}

/* ============================
   MODELOS
   ============================ */

class SongNote {
  final String name; // 'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B','R'
  final int octave; // 3..5 (R usa 0)
  final double beats; // 1=negra,2=blanca,0.5=corchea
  const SongNote(this.name, this.octave, this.beats);
  String get id => '$name$octave';

  factory SongNote.fromJson(Map<String, dynamic> j) => SongNote(
    j['name'] as String,
    j['octave'] as int,
    (j['beats'] as num).toDouble(),
  );
}

class Song {
  final String title;
  final int bpm;
  final List<SongNote> notes;
  const Song({required this.title, required this.bpm, required this.notes});

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    title: j['title'] as String,
    bpm: j['bpm'] as int,
    notes: (j['notes'] as List)
        .map((e) => SongNote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

/* ============================
   CARGA DE CANCIONES
   ============================ */

Future<List<Song>> loadSongsFromAssetsDir(String dir) async {
  final manifestStr = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifest = Map<String, dynamic>.from(
    jsonDecode(manifestStr) as Map,
  );

  final folder = dir.replaceAll(RegExp(r'^assets/'), '').replaceAll('/', '');
  final reg = RegExp(
    r'(^|/)assets/(?:assets/)?' + RegExp.escape(folder) + r'/.*\.json$',
    caseSensitive: false,
  );

  final paths = manifest.keys.where((k) => reg.hasMatch(k)).toList()..sort();

  final songs = <Song>[];
  for (final p in paths) {
    try {
      final content = await rootBundle.loadString(p);
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> && decoded.containsKey('songs')) {
        final list = (decoded['songs'] as List)
            .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        songs.addAll(list);
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('title')) {
        songs.add(Song.fromJson(decoded));
      } else {
        debugPrint('Formato de canción no reconocido en $p');
      }
    } catch (e) {
      debugPrint('Error leyendo $p: $e');
    }
  }
  return songs;
}

/* ============================
   UI
   ============================ */

enum PlayMode { free, follow }

class PianoGame extends StatefulWidget {
  const PianoGame({super.key});
  @override
  State<PianoGame> createState() => _PianoGameState();
}

class _PianoGameState extends State<PianoGame> {
  late Future<List<Song>> _futureSongs;
  PlayMode mode = PlayMode.free;
  bool autoplay = false;

  @override
  void initState() {
    super.initState();
    _futureSongs = loadSongsFromAssetsDir('assets/canciones/');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _futureSongs,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snap.data ?? [];
        if (songs.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron canciones en assets/canciones/',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        return _GameScaffold(
          songs: songs,
          mode: mode,
          autoplay: autoplay,
          onMode: (m) => setState(() => mode = m),
          onAutoplay: (v) => setState(() => autoplay = v),
        );
      },
    );
  }
}

class _GameScaffold extends StatefulWidget {
  const _GameScaffold({
    required this.songs,
    required this.mode,
    required this.autoplay,
    required this.onMode,
    required this.onAutoplay,
  });

  final List<Song> songs;
  final PlayMode mode;
  final bool autoplay;
  final ValueChanged<PlayMode> onMode;
  final ValueChanged<bool> onAutoplay;

  @override
  State<_GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<_GameScaffold> {
  late Song current;
  bool loop = false;

  @override
  void initState() {
    super.initState();
    current = widget.songs.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderBar(
          mode: widget.mode,
          onMode: widget.onMode,
          songs: widget.songs,
          current: current,
          onSong: (s) => setState(() => current = s),
          autoplay: widget.autoplay,
          onAutoplay: widget.onAutoplay,
          loop: loop,
          onLoop: (v) => setState(() => loop = v),
        ),

        // ======= PIANO =======
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 5,
              child: PianoRange(
                startOctave: 3,
                endOctaveInclusive: 5,
                mode: widget.mode,
                song: current,
                autoplay: widget.autoplay,
                loop: loop,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ============================
   HEADER RESPONSIVO 
   ============================ */
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.mode,
    required this.onMode,
    required this.songs,
    required this.current,
    required this.onSong,
    required this.autoplay,
    required this.onAutoplay,
    required this.loop,
    required this.onLoop,
  });

  final PlayMode mode;
  final ValueChanged<PlayMode> onMode;

  final List<Song> songs;
  final Song current;
  final ValueChanged<Song> onSong;

  final bool autoplay;
  final ValueChanged<bool> onAutoplay;

  final bool loop;
  final ValueChanged<bool> onLoop;

  @override
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        // ⬇️ Stack para poder superponer el botón invisible
        child: Stack(
          children: [
            // Fondo y contenido del header (igual que antes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEAF6EF)],
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFDDE5ED), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: Offset(0, 10),
                    color: Color(0x33000000),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Lado izquierdo fijo (no se escala)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFFAF3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          offset: Offset(0, 4),
                          color: Color(0x22059C6B),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.piano_rounded,
                      size: 20,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Piano Sensorial',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BpmBadge(),

                  // --- Bloque derecho ocupa TODO el espacio restante
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ModeChips(mode: mode, onMode: onMode),

                        if (mode == PlayMode.follow) ...[
                          const SizedBox(width: 12),

                          // El dropdown se adapta con elipsis: usa el espacio que quede
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: _SongDropdown(
                                songs: songs,
                                current: current,
                                onChanged: onSong,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Controles con ancho natural (no se escalan).
                          _FollowControls(
                            autoplay: autoplay,
                            onAutoplay: onAutoplay,
                            loop: loop,
                            onLoop: onLoop,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================
   CONTROLES HEADER
   ============================ */

class _SongDropdown extends StatelessWidget {
  const _SongDropdown({
    required this.songs,
    required this.current,
    required this.onChanged,
  });

  final List<Song> songs;
  final Song current;
  final ValueChanged<Song> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Song>(
          value: current,
          isDense: true,
          isExpanded: true, // usa todo el ancho del SizedBox padre
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: Color(0xFF111827),
          ),
          alignment: Alignment.centerLeft,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          menuMaxHeight: 360,
          items: [
            for (final s in songs)
              DropdownMenuItem<Song>(
                value: s,
                child: Text(
                  s.title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(color: Color(0xFF111827)),
                ),
              ),
          ],
          onChanged: (s) => s != null ? onChanged(s) : null,
        ),
      ),
    );
  }
}

class _FollowControls extends StatelessWidget {
  const _FollowControls({
    required this.autoplay,
    required this.onAutoplay,
    required this.loop,
    required this.onLoop,
  });

  final bool autoplay;
  final ValueChanged<bool> onAutoplay;
  final bool loop;
  final ValueChanged<bool> onLoop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Autoplay',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: autoplay,
            onChanged: onAutoplay,
            activeColor: const Color(0xFF059669),
            activeTrackColor: const Color(0xFFBBF7D0),
            inactiveThumbColor: const Color(0xFF6B7280),
            inactiveTrackColor: const Color(0xFFD1D5DB),
          ),
          const SizedBox(width: 12),
          const Text(
            'Bucle',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: loop,
            onChanged: onLoop,
            activeColor: const Color(0xFF059669),
            activeTrackColor: const Color(0xFFBBF7D0),
            inactiveThumbColor: const Color(0xFF6B7280),
            inactiveTrackColor: const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.mode, required this.onMode});
  final PlayMode mode;
  final ValueChanged<PlayMode> onMode;

  @override
  Widget build(BuildContext context) {
    const selectedBg = Color(0xFF10B981);
    const selectedShadow = Color(0x4010B981);
    const idleBg = Color(0xFFFFFFFF);
    const stroke = Color(0xFFE5E7EB);

    Widget chip(
      String text,
      bool selected,
      VoidCallback onTap, {
      IconData? icon,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedBg : idleBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: stroke),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      blurRadius: 12,
                      color: selectedShadow,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      blurRadius: 8,
                      color: Color(0x0F000000),
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF111827),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(
          'Libre',
          mode == PlayMode.free,
          () => onMode(PlayMode.free),
          icon: Icons.touch_app_rounded,
        ),
        chip(
          'Seguir canción',
          mode == PlayMode.follow,
          () => onMode(PlayMode.follow),
          icon: Icons.route_rounded,
        ),
      ],
    );
  }
}

class _BpmBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_GameScaffoldState>();
    final bpm = state?.current.bpm ?? 100;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF065F46)),
          const SizedBox(width: 6),
          Text(
            '$bpm BPM',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================
   ÍNDICE DE ASSETS (piano)
   ============================ */

class AssetIndex {
  final Map<String, String> _pathByCanonical = {}; // "C#4" -> "piano/C#4.mp3"
  static const _flatToSharp = <String, String>{
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  static String _canonical(String letter, String acc, String oct) {
    final L = letter.toUpperCase();
    final a = (acc == '-' ? '#' : acc); // 'c-4' -> C#4
    return '$L$a$oct';
  }

  static AssetIndex fromManifest(Map<String, dynamic> manifest) {
    final idx = AssetIndex();
    final reg = RegExp(r'(^|/)assets/(?:assets/)?piano/', caseSensitive: false);
    final keys = manifest.keys.where((k) => reg.hasMatch(k));

    final nameReg = RegExp(r'([^/]+)\.(mp3|wav|ogg)$', caseSensitive: false);
    final noteReg = RegExp(r'^([A-Ga-g])([#b-]?)(\d)$');

    for (final rawPath in keys) {
      final m1 = nameReg.firstMatch(rawPath);
      if (m1 == null) continue;
      final base = m1.group(1)!;
      final m2 = noteReg.firstMatch(base);
      if (m2 == null) continue;

      final letter = m2.group(1)!;
      final acc = m2.group(2) ?? '';
      final oct = m2.group(3)!;
      final key = _canonical(letter, acc, oct);

      final normalized = rawPath.replaceFirst(
        RegExp(r'^(?:assets/)+', caseSensitive: false),
        '',
      );
      idx._pathByCanonical[key] = normalized; // "piano/C4.mp3"
    }
    return idx;
  }

  String? pathFor(String name, int octave) {
    final reg = RegExp(r'^([A-Ga-g])([#b]?)$');
    final m = reg.firstMatch(name);
    if (m == null) return null;
    final letter = m.group(1)!;
    final acc = m.group(2) ?? '';
    final key = _canonical(letter, acc, octave.toString());
    final direct = _pathByCanonical[key];
    if (direct != null) return direct;

    if (acc == 'b') {
      final sharp = _flatToSharp['${letter.toUpperCase()}b'];
      if (sharp != null) {
        final alt = '$sharp$octave';
        return _pathByCanonical[alt];
      }
    }
    return null;
  }

  static bool isLowLatencyPath(String path) =>
      path.toLowerCase().endsWith('.wav') ||
      path.toLowerCase().endsWith('.ogg');
}

/* ============================
   CACHE GLOBAL DEL ÍNDICE
   ============================ */

class AssetIndexCache {
  static AssetIndex? _instance;

  static Future<AssetIndex> instance() async {
    final cached = _instance;
    if (cached != null) return cached;
    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final manifest = Map<String, dynamic>.from(jsonDecode(manifestStr) as Map);
    _instance = AssetIndex.fromManifest(manifest);
    return _instance!;
  }
}

/* ============================
   COMPENSACIÓN DE LATENCIA
   ============================ */

class LatencyCompensator {
  int _estimateUs; // microsegundos
  LatencyCompensator({int initialUs = 30000})
    : _estimateUs = initialUs; // ~30 ms
  int get leadUs => _estimateUs;

  // EWMA con α = 1/8
  void addSample(Duration d) {
    final us = d.inMicroseconds;
    _estimateUs = ((_estimateUs * 7) + us) >> 3;
    if (_estimateUs < 0) _estimateUs = 0;
    // límite opcional: _estimateUs = _estimateUs.clamp(0, 300000);
  }
}

/* ============================
   THROTTLE POR NOTA (anti-atracón)
   ============================ */

class NoteThrottle {
  final int minGapUs;
  final Map<String, int> _lastUs = {};
  NoteThrottle({this.minGapUs = 12000}); // ~12 ms por nota

  bool shouldPlay(String noteId, int nowUs) {
    final last = _lastUs[noteId];
    if (last == null || (nowUs - last) >= minGapUs) {
      _lastUs[noteId] = nowUs;
      return true;
    }
    return false;
  }
}

/* ============================
   AUDIO POOLS (robustos)
   ============================ */

class AudioPool {
  final int size;
  final PlayerMode mode;
  late final List<AudioPlayer> _players;
  int _cursor = 0;

  AudioPool({this.size = 16, this.mode = PlayerMode.mediaPlayer}) {
    _players = List.generate(size, (_) => AudioPlayer());
    for (final p in _players) {
      p.setReleaseMode(ReleaseMode.stop);
      p.setPlayerMode(mode);
    }
  }

  Future<void> play(
    String assetPath, {
    void Function(Duration startDelay)? onStart,
  }) async {
    assert(
      !assetPath.startsWith('assets/'),
      'AssetSource recibe rutas relativas (sin "assets/"): $assetPath',
    );

    _cursor = (_cursor + 1) % size;
    final p = _players[_cursor];

    try {
      await p.stop();

      // medir latencia hasta "playing"
      final sw = Stopwatch()..start();
      StreamSubscription<PlayerState>? sub;
      Timer? killSwitch;
      sub = p.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.playing) {
          killSwitch?.cancel();
          sub?.cancel();
          onStart?.call(sw.elapsed);
        }
      });
      killSwitch = Timer(const Duration(milliseconds: 600), () {
        sub?.cancel();
      });

      await p.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error reproduciendo $assetPath: $e');
    }
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}

/* ============================
   PIANO + SCHEDULER (Ticker) + BUCLE
   ============================ */

class PianoRange extends StatefulWidget {
  const PianoRange({
    super.key,
    required this.startOctave,
    required this.endOctaveInclusive,
    this.mode = PlayMode.free,
    this.song,
    this.autoplay = false,
    this.loop = false,
  });

  final int startOctave;
  final int endOctaveInclusive;
  final PlayMode mode;
  final Song? song;
  final bool autoplay;
  final bool loop;

  @override
  State<PianoRange> createState() => _PianoRangeState();
}

class _PianoRangeState extends State<PianoRange>
    with SingleTickerProviderStateMixin {
  final _pressed = <String>{};

  // Pools
  late final AudioPool _audioLow = AudioPool(
    size: 18,
    mode: PlayerMode.lowLatency,
  );
  late final AudioPool _audioMp3 = AudioPool(
    size: 14,
    mode: PlayerMode.mediaPlayer,
  );

  // Índice de assets
  AssetIndex? _assetIndex;

  // Teclado
  static const _whiteLetters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const _blackNames = ['Db', 'Eb', 'Gb', 'Ab', 'Bb'];

  // Diseño
  static const _blackKeyWidthRatio = 0.62;
  static const _blackKeyHeightRatio = 0.62;
  static const _whitePressScale = 0.97;
  static const _blackPressScale = 0.94;
  static const _animationDuration = Duration(milliseconds: 60);

  static const _leftWhiteOfBlack = {
    'Db': 'C',
    'Eb': 'D',
    'Gb': 'F',
    'Ab': 'G',
    'Bb': 'A',
  };

  late final List<_Note> whites = _buildWhiteNotes();
  late final List<_Note> blacks = _buildBlackNotes();
  late final Map<String, int> _whiteIndexMap = {
    for (int i = 0; i < whites.length; i++) whites[i].id: i,
  };

  // Follow (scheduler)
  late final Ticker _ticker; // único ticker
  List<int> _boundariesUs = [];
  int _songTotalUs = 1;
  int _usPerBeat = 600000;
  int _songIndex = 0;
  SongNote? _target;
  int _lastTWithinUs = -1;
  final LatencyCompensator _latency = LatencyCompensator(initialUs: 30000);
  int _nextBoundaryUs = 0;
  int _lastLeadUs = -1;

  // Blink repetición
  Timer? _blinkTimer;
  bool _blinkActive = false;

  // Throttle por nota (modo libre)
  final NoteThrottle _throttle = NoteThrottle(minGapUs: 12000);

  bool get _isFollow => widget.mode == PlayMode.follow;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    AssetIndexCache.instance().then((idx) {
      if (!mounted) return;
      setState(() => _assetIndex = idx);
    });
    _rebuildScheduleAndMaybeStart();
  }

  @override
  void didUpdateWidget(PianoRange old) {
    super.didUpdateWidget(old);
    if (widget.mode != old.mode ||
        widget.song != old.song ||
        widget.autoplay != old.autoplay ||
        widget.loop != old.loop) {
      _rebuildScheduleAndMaybeStart();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blinkTimer?.cancel();
    _audioLow.dispose();
    _audioMp3.dispose();
    super.dispose();
  }

  List<_Note> _buildWhiteNotes() {
    final res = <_Note>[];
    for (
      int oct = widget.startOctave;
      oct <= widget.endOctaveInclusive;
      oct++
    ) {
      final letters = (oct == widget.endOctaveInclusive)
          ? ['C']
          : _whiteLetters;
      for (final l in letters) {
        res.add(_Note(letter: l, octave: oct, isBlack: false));
      }
    }
    return res;
  }

  List<_Note> _buildBlackNotes() {
    final res = <_Note>[];
    for (int oct = widget.startOctave; oct < widget.endOctaveInclusive; oct++) {
      for (final name in _blackNames) {
        res.add(_Note(letter: name, octave: oct, isBlack: true));
      }
    }
    return res;
  }

  int _indexOfWhite(String letter, int octave) =>
      _whiteIndexMap['$letter$octave'] ?? -1;

  static bool _isBlackName(String name) =>
      name == 'Db' ||
      name == 'Eb' ||
      name == 'Gb' ||
      name == 'Ab' ||
      name == 'Bb';
  static bool _isRestName(String name) => name == 'R';

  /* ---------- Scheduler alta precisión ---------- */

  void _rebuildScheduleAndMaybeStart() {
    _ticker.stop();
    _blinkTimer?.cancel();
    _blinkActive = false;

    _songIndex = 0;
    _target = null;
    _boundariesUs = [];
    _songTotalUs = 1;
    _lastTWithinUs = -1;
    _nextBoundaryUs = 0;
    _lastLeadUs = -1;

    if (_isFollow && widget.song != null) {
      final bpm = widget.song!.bpm;
      _usPerBeat = (60000000 / bpm).round();

      double sumBeats = 0;
      final notes = widget.song!.notes;
      _boundariesUs = List.filled(notes.length, 0);
      for (int i = 0; i < notes.length; i++) {
        sumBeats += notes[i].beats;
        _boundariesUs[i] = (_usPerBeat * sumBeats).round();
      }
      _songTotalUs = _boundariesUs.last;

      _songIndex = 0;
      _target = notes[0];
      _nextBoundaryUs = _boundariesUs[0];

      if (widget.autoplay) _autoPlayCurrent();
      _ticker.start();
    }

    setState(() {});
  }

  void _onTick(Duration elapsed) {
    final song = widget.song;
    if (song == null || !_isFollow) return;
    final len = song.notes.length;
    if (len == 0) return;

    final nowUs = elapsed.inMicroseconds;
    final tWithin = nowUs % _songTotalUs;

    // Fin de ciclo: si no hay bucle, parar
    if (_lastTWithinUs != -1 && tWithin < _lastTWithinUs && !widget.loop) {
      _ticker.stop();
      _lastTWithinUs = -1;
      return;
    }
    _lastTWithinUs = tWithin;

    if (widget.autoplay) {
      // Normalizamos el lead dentro del ciclo para evitar ráfagas en el wrap
      final tLeadMod = (tWithin + _latency.leadUs) % _songTotalUs;

      bool crossedArcMod(int start, int end, int x, int total) {
        if (start == end) return false;
        if (start < end) return x > start && x <= end;
        return x > start || x <= end; // arco envuelto
      }

      if (widget.loop) {
        int prevLead = (_lastLeadUs < 0) ? tLeadMod : _lastLeadUs;

        int guard = 0;
        const int MAX_STEPS = 8;
        while (guard++ < MAX_STEPS &&
            crossedArcMod(prevLead, tLeadMod, _nextBoundaryUs, _songTotalUs)) {
          final next = (_songIndex + 1) % len;
          _setStep(next, fromScheduler: true);
          _autoPlayCurrent();

          // avanza el cursor del arco para no re-disparar en este mismo tick
          prevLead = _nextBoundaryUs;
        }
        _lastLeadUs = tLeadMod;
      } else {
        // Sin bucle: comparar con tiempo absoluto
        final tLeadRaw = elapsed.inMicroseconds + _latency.leadUs;
        int guard = 0;
        const int MAX_STEPS = 8;
        while (guard++ < MAX_STEPS && tLeadRaw >= _nextBoundaryUs) {
          final next = (_songIndex + 1) % len;
          _setStep(next, fromScheduler: true);
          _autoPlayCurrent();
          if (_songIndex == len - 1 && tLeadRaw >= _songTotalUs) {
            _ticker.stop();
            break;
          }
        }
      }
    }
  }

  /* ---------- Paso / blink ---------- */

  void _setStep(int idx, {required bool fromScheduler}) {
    final song = widget.song;
    if (song == null) return;

    final prevId = _target?.id;
    _songIndex = idx;
    _target = song.notes[_songIndex];

    if (fromScheduler) {
      _nextBoundaryUs = _boundariesUs[_songIndex];
    }

    if (_target != null &&
        !_isRestName(_target!.name) &&
        prevId != null &&
        _target!.id == prevId) {
      _triggerBlink();
    } else {
      _cancelBlink();
    }
    setState(() {});
  }

  /* ---------- Repro ---------- */

  Future<void> _playNote(_Note n) async {
    final idx = _assetIndex;
    String? path;
    if (idx == null) {
      path = 'piano/${n.letter}${n.octave}.mp3';
      await _audioMp3.play(path, onStart: _latency.addSample);
      return;
    }
    path = idx.pathFor(n.letter, n.octave);
    if (path == null) {
      debugPrint('⚠️ Asset no encontrado para ${n.letter}${n.octave}');
      return;
    }
    final pool = AssetIndex.isLowLatencyPath(path) ? _audioLow : _audioMp3;
    await pool.play(path, onStart: _latency.addSample);
  }

  void _autoPlayCurrent() {
    final t = _target;
    if (t == null || _isRestName(t.name)) return;
    final n = _Note(
      letter: t.name,
      octave: t.octave,
      isBlack: _isBlackName(t.name),
    );
    // no esperamos el Future
    // ignore: discarded_futures
    _playNote(n);
  }

  /* ---------- Interacción ---------- */

  void _pressUser(_Note n) {
    final id = n.id;
    _pressed.add(id);
    setState(() {}); // pintar presión

    if (_isFollow && _target != null && !widget.autoplay) {
      final expected = _target!.id;
      if (id == expected) {
        // ignore: discarded_futures
        _playNote(n);
        final len = widget.song!.notes.length;
        int next = _songIndex + 1;
        if (next >= len) {
          if (widget.loop) {
            next = 0;
          } else {
            _cancelBlink();
            setState(() {});
            return;
          }
        }
        _setStep(next, fromScheduler: false);
      } else {
        // incorrecta: silencio
      }
    } else {
      // Modo libre (o follow+autoplay): throttle por nota para no saturar
      final nowUs = DateTime.now().microsecondsSinceEpoch;
      if (!(_isFollow && widget.autoplay) && _throttle.shouldPlay(id, nowUs)) {
        // ignore: discarded_futures
        _playNote(n);
      }
    }
  }

  void _releaseUser(_Note n) {
    if (_pressed.remove(n.id)) setState(() {});
  }

  /* ---------- Blink ---------- */

  void _triggerBlink() {
    _blinkTimer?.cancel();
    _blinkActive = true;
    setState(() {});
    _blinkTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _blinkActive = false;
      setState(() {});
    });
  }

  void _cancelBlink() {
    _blinkTimer?.cancel();
    if (_blinkActive) {
      _blinkActive = false;
      setState(() {});
    }
  }

  /* ---------- Render ---------- */

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          final whitesLen = whites.length;
          final whiteW = w / whitesLen;
          final whiteH = h;
          final blackW = whiteW * _blackKeyWidthRatio;
          final blackH = h * _blackKeyHeightRatio;

          return Stack(
            children: [
              // Blancas
              ...whites.asMap().entries.map((entry) {
                final i = entry.key;
                final note = entry.value;
                final id = note.id;
                final pressed = _pressed.contains(id);

                final isTarget =
                    (_isFollow &&
                    _target != null &&
                    !_isRestName(_target!.name) &&
                    _target!.id == id);
                final showTarget = isTarget && !_blinkActive;

                return Positioned(
                  left: i * whiteW,
                  top: 0,
                  width: whiteW,
                  height: whiteH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _pressUser(note),
                    onTapUp: (_) => _releaseUser(note),
                    onTapCancel: () => _releaseUser(note),
                    child: AnimatedScale(
                      scale: pressed ? _whitePressScale : 1.0,
                      duration: _animationDuration,
                      child: Container(
                        decoration: BoxDecoration(
                          color: showTarget
                              ? const Color(0xFFDFFFE2)
                              : Colors.white,
                          border: Border.all(
                            color: showTarget
                                ? const Color(0xFF22C55E)
                                : Colors.black,
                            width: showTarget ? 2 : 1,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Negras
              ...blacks.map((note) {
                final leftWhite = _leftWhiteOfBlack[note.letter]!;
                final leftIndex = _indexOfWhite(leftWhite, note.octave);
                if (leftIndex == -1) return const SizedBox.shrink();

                final id = note.id;
                final pressed = _pressed.contains(id);

                final isTarget =
                    (_isFollow &&
                    _target != null &&
                    !_isRestName(_target!.name) &&
                    _target!.id == id);
                final showTarget = isTarget && !_blinkActive;

                final left = (leftIndex + 1) * whiteW - blackW / 2;

                return Positioned(
                  left: left,
                  top: 0,
                  width: blackW,
                  height: blackH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _pressUser(note),
                    onTapUp: (_) => _releaseUser(note),
                    onTapCancel: () => _releaseUser(note),
                    child: AnimatedScale(
                      scale: pressed ? _blackPressScale : 1.0,
                      duration: _animationDuration,
                      child: Container(
                        decoration: BoxDecoration(
                          color: showTarget
                              ? const Color(0xFF14532D)
                              : Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6,
                              offset: Offset(0, 3),
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _Note {
  final String letter; // 'C','Db',...
  final int octave; // 3..5
  final bool isBlack;
  const _Note({
    required this.letter,
    required this.octave,
    required this.isBlack,
  });
  String get id => '$letter$octave';
}
