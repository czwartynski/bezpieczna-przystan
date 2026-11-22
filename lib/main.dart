import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'audio.dart';

void main() => runApp(
  MaterialApp(
    title: 'Bezpieczna Przystań',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pl'),
    supportedLocales: const [Locale('pl')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff7148a3)),
      scaffoldBackgroundColor: const Color(0xfffaf6ff),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xfff1e8fc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
    ),
    home: const Przystan(),
  ),
);

const _modules = [
  ('Porozmawiaj ze wsparciem', Icons.forum_outlined),
  ('Dowiedz się więcej', Icons.menu_book_outlined),
  ('Mój dziennik', Icons.edit_note),
  ('Plan bezpieczeństwa', Icons.fact_check_outlined),
  ('Rejestrator zdarzeń', Icons.mic_none),
  ('Znajdź pomoc', Icons.volunteer_activism_outlined),
  ('PANIC', Icons.pan_tool_outlined),
  ('SOS', Icons.sos),
  ('Tryb neutralny', Icons.notes),
  ('Zmiana ikony aplikacji', Icons.apps),
  ('PIN i ustawienia prywatności', Icons.lock_outline),
];

class Przystan extends StatefulWidget {
  const Przystan({super.key});

  @override
  State<Przystan> createState() => _PrzystanState();
}

class _PrzystanState extends State<Przystan> {
  final _audio = Audio();
  final _plan = TextEditingController();
  final _neutral = TextEditingController();
  String _savedPlan = '';
  List<Map<String, dynamic>> _entries = [];
  List<Recording> _recordings = [];
  int? _started;
  String? _playing;
  int _page = -2;
  bool _busy = false;
  bool _refreshing = false;
  bool _loaded = false;
  String? _error;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer.cancel();
    _plan.dispose();
    _neutral.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _audio.load();
      if (!mounted) return;
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        _entries = (saved['entries'] as List).cast<Map<String, dynamic>>();
        _savedPlan = saved['plan'] as String;
        _plan.text = _savedPlan;
      }
      setState(() => _loaded = true);
    } catch (_) {
      _show('Nie udało się wczytać danych lokalnych.');
    }
  }

  Future<void> _refresh({bool force = false}) async {
    if (!force && (_refreshing || _busy)) return;
    _refreshing = true;
    try {
      final status = await _audio.status();
      if (!mounted) return;
      setState(() {
        _recordings = status.recordings;
        _started = status.started;
        _playing = status.playing;
      });
    } catch (_) {
      if (force) rethrow;
    } finally {
      _refreshing = false;
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh(force: true);
    } catch (error) {
      final message = switch (error) {
        PlatformException(:final message) =>
          message ?? 'Operacja się nie powiodła.',
        _ => error.toString().replaceFirst('Error: ', ''),
      };
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({List<Map<String, dynamic>>? entries}) async {
    final plan = entries == null ? _plan.text : _savedPlan;
    await _audio.save(
      jsonEncode({'entries': entries ?? _entries, 'plan': plan}),
    );
    _savedPlan = plan;
    if (mounted && entries != null) setState(() => _entries = entries);
  }

  Future<void> _addEntry([Recording? recording]) async {
    final input = TextEditingController();
    String? value;
    try {
      value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(recording == null ? 'Nowy wpis' : 'Wpis z nagraniem'),
          content: TextField(
            controller: input,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Treść wpisu'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
    if (value == null || (value.isEmpty && recording == null) || !mounted)
      return;
    final entry = <String, dynamic>{
      'text': value,
      'created': DateTime.now().millisecondsSinceEpoch,
      'recording': recording?.id,
    };
    await _run(() => _save(entries: [entry, ..._entries]));
  }

  Future<void> _delete(Recording recording) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć nagranie?'),
        content: const Text(
          'Załącznik przestanie być dostępny we wpisach dziennika.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted)
      await _run(() => _audio.delete(recording.id));
  }

  void _go(int page) => setState(() {
    _page = page;
    _error = null;
  });

  String _date(DateTime date) {
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatCompactDate(date)} • ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  String _time(Duration duration) {
    final seconds = math.max(0, duration.inSeconds);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _card(String title, String body, {IconData? icon}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 30),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    ),
  );

  Widget _landing() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(32),
            ),
            child: CustomPaint(painter: _Lotus(colors.primary)),
          ),
          const SizedBox(height: 28),
          Text(
            'Bezpieczna Przystań',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Informacje i narzędzia dla osób doświadczających przemocy.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _go(-1),
            child: const Text('Przejdź do aplikacji'),
          ),
        ],
      ),
    );
  }

  List<Widget> _home(double width) => [
    Text(
      'Jak możemy Ci pomóc?',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 16),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < _modules.length; i++)
          SizedBox(
            width: width >= 660 ? (width - 12) / 2 : width,
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                leading: Icon(_modules[i].$2),
                title: Text(_modules[i].$1),
                subtitle: [0, 6, 7, 9].contains(i)
                    ? const Text('Moduł w trakcie budowy')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _go(i),
              ),
            ),
          ),
      ],
    ),
  ];

  Widget _play(String id) => IconButton(
    tooltip: _playing == id ? 'Zatrzymaj odtwarzanie' : 'Odtwórz',
    onPressed: _busy || _started != null
        ? null
        : () => _run(() => _playing == id ? _audio.pause() : _audio.play(id)),
    icon: Icon(
      _playing == id ? Icons.stop_circle_outlined : Icons.play_circle_outline,
    ),
  );

  List<Widget> _recorder() => [
    _card(
      kIsWeb ? 'Nagrania testowe' : 'Nagrywanie na Androidzie',
      kIsWeb
          ? 'Używaj wyłącznie nagrań testowych. Nagrania są dostępne do odświeżenia lub zamknięcia karty. Przeglądarka może przerwać zapis po zablokowaniu urządzenia.'
          : 'Rozpocznij nagrywanie przy otwartej aplikacji. Usługa z powiadomieniem umożliwia nagrywanie w tle i przy zablokowanym ekranie. System może przerwać nagrywanie. Pliki są lokalne i aplikacja ich nie szyfruje.',
    ),
    const SizedBox(height: 16),
    Center(
      child: FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(_started == null ? _audio.start : _audio.stop),
        icon: Icon(_started == null ? Icons.mic : Icons.stop),
        label: Text(
          _started == null
              ? 'Rozpocznij nagrywanie'
              : 'Zatrzymaj • ${_time(Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - _started!))}',
        ),
      ),
    ),
    const SizedBox(height: 24),
    Text('Nagrania', style: Theme.of(context).textTheme.titleLarge),
    if (_recordings.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Tu pojawią się zapisane nagrania.'),
      ),
    for (final item in _recordings)
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(_date(item.created)),
            subtitle: Text(_time(item.duration)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _play(item.id),
                IconButton(
                  tooltip: 'Dodaj do dziennika',
                  onPressed: _busy || !_loaded ? null : () => _addEntry(item),
                  icon: const Icon(Icons.note_add_outlined),
                ),
                IconButton(
                  tooltip: 'Usuń nagranie',
                  onPressed: _busy ? null : () => _delete(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
  ];

  List<Widget> _journal() => [
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: _busy || !_loaded ? null : () => _addEntry(),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj wpis'),
      ),
    ),
    if (_entries.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Tu pojawią się Twoje wpisy.'),
      ),
    for (final entry in _entries)
      Card(
        child: ListTile(
          title: Text(
            (entry['text'] as String).isEmpty
                ? 'Wpis z nagraniem'
                : entry['text'] as String,
          ),
          subtitle: Text(
            _date(DateTime.fromMillisecondsSinceEpoch(entry['created'] as int)),
          ),
          trailing: entry['recording'] == null
              ? null
              : _recordings.any((item) => item.id == entry['recording'])
              ? _play(entry['recording'] as String)
              : const Tooltip(
                  message: 'Nagranie usunięte',
                  child: Icon(Icons.link_off),
                ),
        ),
      ),
  ];

  List<Widget> _content(double width) => switch (_page) {
    -2 => [_landing()],
    -1 => _home(width),
    1 => [
      _card(
        'Przemoc psychiczna',
        'Może obejmować poniżanie, groźby, izolowanie od bliskich i kontrolowanie codziennych decyzji.',
        icon: Icons.psychology_outlined,
      ),
      _card(
        'Przemoc fizyczna',
        'Może obejmować popychanie, szarpanie, bicie lub ograniczanie swobody poruszania się.',
        icon: Icons.shield_outlined,
      ),
      _card(
        'Gdzie szukać wsparcia',
        'Możesz porozmawiać z zaufaną osobą lub skorzystać z pomocy specjalistów.',
      ),
      TextButton(
        onPressed: () => _go(5),
        child: const Text('Zobacz możliwości pomocy'),
      ),
    ],
    2 => _journal(),
    3 => [
      _card(
        'Przygotuj własny plan',
        'Zapisz bezpieczne miejsce, sposób dotarcia tam oraz osoby, do których możesz się zwrócić.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _plan,
        enabled: _loaded && !_busy,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(
          labelText: 'Mój plan',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: !_loaded || _busy
              ? null
              : () => _run(() async {
                  await _save();
                  _show('Plan został zapisany.');
                }),
          child: const Text('Zapisz plan'),
        ),
      ),
    ],
    4 => _recorder(),
    5 => [
      _contact(
        '112',
        'Numer alarmowy',
        'Dzwoń, gdy życie lub zdrowie jest bezpośrednio zagrożone.',
      ),
      _contact(
        '800 120 002',
        'Niebieska Linia',
        'Bezpłatna pomoc dla osób doświadczających przemocy domowej, dostępna przez całą dobę.',
      ),
      _card(
        'Pomoc w Twojej okolicy',
        'Ośrodek interwencji kryzysowej lub ośrodek pomocy społecznej może pomóc Ci ustalić dostępne formy wsparcia.',
      ),
    ],
    8 => [
      TextField(
        controller: _neutral,
        minLines: 6,
        maxLines: 16,
        decoration: const InputDecoration(
          labelText: 'Notatka robocza',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    10 => [
      _card('PIN', 'Moduł w trakcie budowy.'),
      _card(
        'Przechowywanie danych',
        kIsWeb
            ? 'Dane demonstracyjne są w pamięci bieżącej karty. Wprowadzaj wyłącznie dane testowe.'
            : 'Dane są w pamięci prywatnej aplikacji. Ta wersja nie szyfruje ich na poziomie aplikacji i nie jest zabezpieczonym magazynem dowodów.',
      ),
    ],
    _ => [_card(_modules[_page].$1, 'Moduł w trakcie budowy')],
  };

  Widget _contact(String number, String title, String subtitle) => Card(
    child: ListTile(
      title: Text('$title · $number'),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Kopiuj numer $number',
        icon: const Icon(Icons.copy),
        onPressed: () async {
          try {
            await Clipboard.setData(
              ClipboardData(text: number.replaceAll(' ', '')),
            );
            _show('Numer został skopiowany.');
          } catch (_) {
            _show('Nie udało się skopiować numeru.');
          }
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _page == -2,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _go(_page >= 0 ? -1 : -2);
    },
    child: Scaffold(
      appBar: _page == -2
          ? null
          : AppBar(
              title: Text(
                _page == -1
                    ? 'Bezpieczna Przystań'
                    : _page == 8
                    ? 'Notatnik'
                    : _modules[_page].$1,
              ),
              leading: BackButton(onPressed: () => _go(_page == -1 ? -2 : -1)),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: LayoutBuilder(
              builder: (context, box) => ListView(
                key: ValueKey(_page),
                padding: const EdgeInsets.all(20),
                children: [
                  if (kIsWeb && _page != 8)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Demo w przeglądarce · Używaj wyłącznie danych testowych.',
                      ),
                    ),
                  if (_started != null && _page != 4)
                    ListTile(
                      leading: const Icon(Icons.mic),
                      title: const Text('Trwa nagrywanie'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _go(4),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ..._content(math.max(0, box.maxWidth - 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Lotus extends CustomPainter {
  const _Lotus(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;
    final center = Path()
      ..moveTo(50, 69)
      ..cubicTo(31, 56, 39, 36, 50, 25)
      ..cubicTo(61, 36, 69, 56, 50, 69);
    canvas.drawPath(center, paint);
    for (final direction in [-1, 1]) {
      double x(double offset) => 50 + direction * offset;
      final petal = Path()
        ..moveTo(50, 69)
        ..cubicTo(x(19), 74, x(31), 60, x(34), 47)
        ..quadraticBezierTo(x(17), 45, x(11), 54);
      canvas.drawPath(petal, paint);
      final inner = Path()
        ..moveTo(x(25), 48)
        ..quadraticBezierTo(x(24), 38, x(18), 33)
        ..quadraticBezierTo(x(11), 37, x(10), 44);
      canvas.drawPath(inner, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Lotus oldDelegate) => oldDelegate.color != color;
}
