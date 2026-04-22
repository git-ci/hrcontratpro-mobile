import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

const _statuses = {
  'present': {'label': 'Présence', 'icon': '✅', 'color': AppTheme.success},
  'absent': {'label': 'Absence', 'icon': '❌', 'color': AppTheme.danger},
  'sick': {'label': 'Maladie', 'icon': '🏥', 'color': AppTheme.info},
  'maternity': {'label': 'Maternité', 'icon': '🤱', 'color': AppTheme.info},
  'leave': {'label': 'Congés', 'icon': '🏖️', 'color': AppTheme.warning},
  'work_accident': {
    'label': 'Accident travail',
    'icon': '⚠️',
    'color': AppTheme.danger
  },
  'suspension': {
    'label': 'Mise à pied',
    'icon': '🚫',
    'color': AppTheme.textMuted
  },
  'permission': {
    'label': 'Permission',
    'icon': '🕐',
    'color': AppTheme.warning
  },
  'mission': {'label': 'Mission', 'icon': '🚀', 'color': AppTheme.success},
  'holiday': {'label': 'Jour férié', 'icon': '🎉', 'color': AppTheme.info},
};

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: AuthService.isEmp ? 1 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Pointage'),
        actions: [
          if (AuthService.isRH)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scanner QR',
              onPressed: () => context.go('/${AuthService.role}/scan'),
            ),
        ],
        bottom: AuthService.isEmp
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Saisie journalière'),
                  Tab(text: 'Historique')
                ],
              ),
      ),
      body: AuthService.isEmp
          ? const _MyAttendanceTab()
          : TabBarView(controller: _tabs, children: const [
              _DailyEntryTab(),
              _HistoryTab(),
            ]),
    );
  }
}

// ── Saisie journalière (RH/DG) ─────────────────────────────────────────────────
class _DailyEntryTab extends StatefulWidget {
  const _DailyEntryTab();
  @override
  State<_DailyEntryTab> createState() => _DailyEntryTabState();
}

class _DailyEntryTabState extends State<_DailyEntryTab> {
  DateTime _date = DateTime.now();
  List<dynamic> _employees = [];
  Map<int, Map<String, dynamic>> _attendances = {};
  Map<int, String> _statusMap = {};
  Map<int, String> _notes = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = _fmtDateIso(_date);
      final [empData, attData] = await Future.wait([
        ApiService.getUsers(query: null, page: 1),
        ApiService.getAttendances(params: '?date=$dateStr&per_page=200'),
      ]);
      final emps = ((empData as Map)['data'] ?? []) as List;
      final atts = ((attData as Map)['data'] ?? []) as List;

      final attMap = <int, Map<String, dynamic>>{};
      for (final a in atts) {
        attMap[a['user_id'] as int] = a as Map<String, dynamic>;
      }

      final statMap = <int, String>{};
      final noteMap = <int, String>{};
      for (final e in emps) {
        final id = e['id'] as int;
        statMap[id] = attMap[id]?['status'] ?? 'present';
        noteMap[id] = attMap[id]?['note'] ?? '';
      }

      setState(() {
        _employees = emps;
        _attendances = attMap;
        _statusMap = statMap;
        _notes = noteMap;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final dateStr = _fmtDateIso(_date);
      final rows = _employees.map((e) {
        final id = e['id'] as int;
        return {
          'user_id': id,
          'status': _statusMap[id] ?? 'absent',
          'note': _notes[id] ?? '',
        };
      }).toList();
      await ApiService.bulkAttendance({'date': dateStr, 'attendances': rows});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pointages enregistrés !'),
            backgroundColor: AppTheme.success));
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Sélecteur de date
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _date = _date.subtract(const Duration(days: 1)));
                _load();
              }),
          Expanded(
              child: GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (d != null) {
                setState(() => _date = d);
                _load();
              }
            },
            child: Text(_fmtDateFr(_date),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _date.isBefore(
                      DateTime.now().subtract(const Duration(days: 1)))
                  ? () {
                      setState(
                          () => _date = _date.add(const Duration(days: 1)));
                      _load();
                    }
                  : null),
        ]),
      ),
      const Divider(height: 1),

      Expanded(
        child: _loading
            ? const LoadingWidget()
            : _error != null
                ? ErrorWidget2(message: _error!, onRetry: _load)
                : _employees.isEmpty
                    ? const EmptyWidget(icon: '👥', title: 'Aucun employé')
                    : ListView.builder(
                        itemCount: _employees.length,
                        itemBuilder: (_, i) {
                          final emp = _employees[i] as Map<String, dynamic>;
                          final id = emp['id'] as int;
                          final att = _attendances[id];
                          final status = _statusMap[id] ?? 'present';
                          final cfg = _statusConfig(status);
                          final locked = att?['locked'] == true;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppTheme.primary,
                                          child: Text(
                                              (emp['name'] ?? '?')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(emp['name'] ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14))),
                                      if (locked)
                                        const Icon(Icons.lock,
                                            size: 16,
                                            color: AppTheme.textMuted),
                                      if (att?['source'] == 'qr')
                                        const Text('📷 QR',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.info)),
                                    ]),
                                    const SizedBox(height: 10),
                                    if (!locked)
                                      DropdownButtonFormField<String>(
                                        value: status,
                                        isDense: true,
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          isDense: true,
                                        ),
                                        items: _statuses.keys
                                            .where((s) => s != 'holiday')
                                            .map((s) {
                                          final c = _statusConfig(s);
                                          return DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                  '${c['icon']} ${c['label']}'));
                                        }).toList(),
                                        onChanged: (v) => setState(
                                            () => _statusMap[id] = v ?? status),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: (cfg['color'] as Color)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text(
                                            '${cfg['icon']} ${cfg['label']}',
                                            style: TextStyle(
                                                color: cfg['color'] as Color,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                      ),
                                  ]),
                            ),
                          );
                        },
                      ),
      ),

      // Bouton sauvegarder
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAll,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Enregistrement…' : 'Tout enregistrer'),
            ),
          ),
        ),
      ),
    ]);
  }

  Map<String, dynamic> _statusConfig(String s) {
    return _statuses[s] as Map<String, dynamic>? ??
        <String, dynamic>{'label': s, 'icon': '•', 'color': AppTheme.textMuted};
  }

  String _fmtDateIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtDateFr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Historique (RH/DG) ─────────────────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<dynamic> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getAttendances(
          params:
              '?per_page=50&date_from=${_fmtIso(DateTime.now().subtract(const Duration(days: 30)))}&date_to=${_fmtIso(DateTime.now())}');
      setState(() {
        _records = (data['data'] ?? []) as List;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) return ErrorWidget2(message: _error!, onRetry: _load);
    if (_records.isEmpty)
      return const EmptyWidget(icon: '📅', title: 'Aucun pointage');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _records.length,
        itemBuilder: (_, i) {
          final r = _records[i] as Map<String, dynamic>;
          final s = r['status'] ?? 'absent';
          final cfg = _statuses[s] ??
              {'label': s, 'icon': '•', 'color': AppTheme.textMuted};
          final color = cfg['color'] as Color;

          return Card(
            child: ListTile(
              leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(cfg['icon'] as String,
                          style: const TextStyle(fontSize: 18)))),
              title: Text(r['user']?['name'] ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Row(children: [
                Text(_fmtDateFr(r['date'] ?? ''),
                    style: const TextStyle(fontSize: 12)),
                if (r['site'] != null) ...[
                  const Text(' · ',
                      style: TextStyle(color: AppTheme.textMuted)),
                  Text('🏢 ${r['site']['name']}',
                      style:
                          const TextStyle(fontSize: 11, color: AppTheme.info)),
                ],
              ]),
              trailing: Text(cfg['label'] as String,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  String _fmtIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtDateFr(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}

// ── Chip heure arrivée / départ ────────────────────────────────────────────────
class _TimeChip extends StatelessWidget {
  final String label;
  final String? time;
  final Color color;

  const _TimeChip({required this.label, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    if (time == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label : ',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        Text(time!,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Mon pointage (Employé) ──────────────────────────────────────────────────────
class _MyAttendanceTab extends StatefulWidget {
  const _MyAttendanceTab();
  @override
  State<_MyAttendanceTab> createState() => _MyAttendanceTabState();
}

class _MyAttendanceTabState extends State<_MyAttendanceTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getMyAttendance();
      setState(() {
        _data = data as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) return ErrorWidget2(message: _error!, onRetry: _load);

    final records = (_data?['records'] ?? []) as List;
    final stats = _data?['stats'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        if (stats != null) ...[
          const SectionTitle(title: 'CE MOIS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: StatCard(
                      icon: '✅',
                      value: '${stats['presence_rate'] ?? 0}%',
                      label: 'Taux présence',
                      color: AppTheme.success)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatCard(
                      icon: '📅',
                      value: '${stats['present_count'] ?? 0}',
                      label: 'Jours présents',
                      color: AppTheme.info)),
            ]),
          ),
        ],
        const SectionTitle(title: 'HISTORIQUE'),
        ...records.map((r) {
          final s = r['status'] ?? 'absent';
          final cfg = _statuses[s] ??
              {'label': s, 'icon': '•', 'color': AppTheme.textMuted};
          final color = cfg['color'] as Color;
          final checkinTime  = r['checked_in_at']  as String?;
          final checkoutTime = r['checked_out_at'] as String?;
          final hasTime = checkinTime != null || checkoutTime != null;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(cfg['icon'] as String,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ligne 1 : date + statut
                      Row(children: [
                        Text(_fmtDateFr(r['date'] ?? ''),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(cfg['label'] as String,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11)),
                        ),
                        if (r['source'] == 'qr') ...[
                          const SizedBox(width: 6),
                          const Text('📷 QR',
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.info)),
                        ],
                      ]),
                      // Ligne 2 : arrivée → départ (même ligne)
                      if (hasTime) ...[
                        const SizedBox(height: 5),
                        Row(children: [
                          _TimeChip(
                            label: 'Arrivée',
                            time: checkinTime,
                            color: AppTheme.success,
                          ),
                          if (checkinTime != null && checkoutTime != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('→',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12)),
                            ),
                          _TimeChip(
                            label: 'Départ',
                            time: checkoutTime,
                            color: const Color(0xFFE8590C),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  String _fmtDateFr(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}
