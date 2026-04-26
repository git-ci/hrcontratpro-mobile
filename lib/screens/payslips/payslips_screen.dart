import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';

const List<String> _months = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

// ── Écran principal ───────────────────────────────────────────────────────────
class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});
  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  List<dynamic> _payslips = [];
  bool _loading = true;
  String? _error;

  bool get _isRh => AuthService.isRH;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isRh) {
        final res = await ApiService.getPayslips(params: '?per_page=500');
        setState(() => _payslips = res['data'] ?? []);
      } else {
        final list = await ApiService.getMyPayslips();
        setState(() => _payslips = list);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(_isRh ? 'Bulletins de salaire' : 'Mes bulletins'),
        actions: [
          if (_isRh)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouveau bulletin',
              onPressed: () => _showCreateDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    if (_payslips.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text('Aucun bulletin disponible', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
        ]),
      );
    }

    if (_isRh) return _buildRhList();
    return _buildEmployeeList();
  }

  // ── Vue RH : liste plate avec filtre par année ─────────────────────────────

  Widget _buildRhList() {
    // Grouper par année
    final byYear = <int, List<dynamic>>{};
    for (final s in _payslips) {
      final y = s['year'] as int;
      byYear.putIfAbsent(y, () => []).add(s);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: years.length,
        itemBuilder: (ctx, i) {
          final year = years[i];
          final slips = byYear[year]!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('$year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ...slips.map((s) => _RhPayslipTile(slip: s, onRefresh: _load)),
            const SizedBox(height: 8),
          ]);
        },
      ),
    );
  }

  // ── Vue Employé / DG : groupé par année ───────────────────────────────────

  Widget _buildEmployeeList() {
    final byYear = <int, List<dynamic>>{};
    for (final s in _payslips) {
      final y = s['year'] as int;
      byYear.putIfAbsent(y, () => []).add(s);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: years.length,
        itemBuilder: (ctx, i) {
          final year = years[i];
          final slips = byYear[year]!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('$year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ...slips.map((s) => _EmpPayslipTile(slip: s)),
            const SizedBox(height: 8),
          ]);
        },
      ),
    );
  }

  // ── Dialog création bulletin (RH) ─────────────────────────────────────────

  Future<void> _showCreateDialog(BuildContext context) async {
    // Charger les employés
    Map<String, dynamic>? empRes;
    try {
      empRes = await ApiService.getUsers(query: '', page: 1);
    } catch (_) {}
    final employees = (empRes?['data'] as List?) ?? [];

    if (!context.mounted) return;

    int? selectedUserId;
    int selectedMonth = DateTime.now().month;
    int selectedYear  = DateTime.now().year;
    File? selectedPdf;
    bool uploading = false;
    String? err;

    final years = List.generate(5, (i) => DateTime.now().year - i);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Nouveau bulletin'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Sélection employé
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Employé *'),
                value: selectedUserId,
                items: employees.map<DropdownMenuItem<int>>((e) => DropdownMenuItem(
                  value: e['id'] as int,
                  child: Text(e['name'] as String? ?? ''),
                )).toList(),
                onChanged: (v) => setDlgState(() => selectedUserId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Mois'),
                    value: selectedMonth,
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1, child: Text(_months[i + 1]),
                    )),
                    onChanged: (v) => setDlgState(() => selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Année'),
                    value: selectedYear,
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) => setDlgState(() => selectedYear = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(selectedPdf != null
                    ? selectedPdf!.path.split('/').last
                    : 'Joindre le PDF'),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ['pdf'],
                  );
                  if (result != null && result.files.isNotEmpty) {
                    setDlgState(() => selectedPdf = File(result.files.first.path!));
                  }
                },
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: uploading ? null : () async {
                if (selectedUserId == null) {
                  setDlgState(() => err = 'Sélectionnez un employé.');
                  return;
                }
                setDlgState(() { uploading = true; err = null; });
                try {
                  final slip = await ApiService.createPayslip({
                    'user_id': selectedUserId,
                    'month':   selectedMonth,
                    'year':    selectedYear,
                  });
                  if (selectedPdf != null) {
                    await ApiService.uploadPayslipPdf(slip['id'] as int, selectedPdf!);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bulletin enregistré avec succès.')),
                    );
                  }
                } catch (e) {
                  setDlgState(() { uploading = false; err = e.toString(); });
                }
              },
              child: uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tuile RH ─────────────────────────────────────────────────────────────────

class _RhPayslipTile extends StatefulWidget {
  final Map<String, dynamic> slip;
  final VoidCallback onRefresh;
  const _RhPayslipTile({required this.slip, required this.onRefresh});
  @override
  State<_RhPayslipTile> createState() => _RhPayslipTileState();
}

class _RhPayslipTileState extends State<_RhPayslipTile> {
  bool _uploading = false;
  bool _opening   = false;

  Map<String, dynamic> get s => widget.slip;
  bool get hasPdf => s['has_pdf'] == true;
  String get period => '${_months[s['month'] as int]} ${s['year']}';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accent.withOpacity(0.1),
          child: const Icon(Icons.receipt_long, color: AppTheme.accent),
        ),
        title: Text(s['user']?['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(period),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasPdf) ...[
            _opening
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: AppTheme.accent),
                    tooltip: 'Voir le PDF',
                    onPressed: _openPdf,
                  ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: AppTheme.warning),
              tooltip: 'Remplacer le PDF',
              onPressed: _uploading ? null : _uploadPdf,
            ),
          ] else ...[
            _uploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.attach_file, color: AppTheme.accent),
                    tooltip: 'Joindre PDF',
                    onPressed: _uploadPdf,
                  ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            tooltip: 'Supprimer',
            onPressed: _confirmDelete,
          ),
        ]),
      ),
    );
  }

  Future<void> _openPdf() async {
    setState(() => _opening = true);
    try {
      final bytes = await ApiService.downloadPayslipPdf(s['id'] as int);
      final tmp   = await getTemporaryDirectory();
      final file  = File('${tmp.path}/bulletin_${s['id']}.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir : ${result.message}'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) { setState(() => _opening = false); }
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await ApiService.uploadPayslipPdf(s['id'] as int, File(result.files.first.path!));
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF joint avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) { setState(() => _uploading = false); }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le bulletin'),
        content: Text('Supprimer le bulletin de $period pour ${s['user']?['name'] ?? '—'} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ApiService.deletePayslip(s['id'] as int);
                widget.onRefresh();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ── Tuile Employé ─────────────────────────────────────────────────────────────

class _EmpPayslipTile extends StatefulWidget {
  final Map<String, dynamic> slip;
  const _EmpPayslipTile({required this.slip});
  @override
  State<_EmpPayslipTile> createState() => _EmpPayslipTileState();
}

class _EmpPayslipTileState extends State<_EmpPayslipTile> {
  bool _loading = false;

  Map<String, dynamic> get s => widget.slip;
  bool get hasPdf => s['has_pdf'] == true;
  String get period => '${_months[s['month'] as int]} ${s['year']}';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasPdf ? AppTheme.success.withOpacity(0.1) : AppTheme.border,
          child: Icon(
            hasPdf ? Icons.receipt_long : Icons.receipt_long_outlined,
            color: hasPdf ? AppTheme.success : AppTheme.textMuted,
          ),
        ),
        title: Text(period, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: hasPdf
            ? Text(s['pdf_original_name'] ?? '', style: const TextStyle(fontSize: 12))
            : const Text('PDF non disponible', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: hasPdf
            ? _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppTheme.accent),
                      tooltip: 'Consulter',
                      onPressed: _openPdf,
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, color: AppTheme.info),
                      tooltip: 'Télécharger',
                      onPressed: _downloadPdf,
                    ),
                  ])
            : null,
      ),
    );
  }

  Future<void> _openPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final bytes = await ApiService.downloadPayslipPdf(s['id'] as int);
      final tmp   = await getTemporaryDirectory();
      final file  = File('${tmp.path}/bulletin_${s['id']}.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir : ${result.message}'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _downloadPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final bytes     = await ApiService.downloadPayslipPdf(s['id'] as int);
      final downloads = await getApplicationDocumentsDirectory();
      final filename  = 'bulletin_${period.replaceAll(' ', '_')}.pdf';
      final file      = File('${downloads.path}/$filename');
      await file.writeAsBytes(bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('Enregistré : $filename'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }
}
