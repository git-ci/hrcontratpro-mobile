import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

const _leaveStatuses = {
  'pending':  {'label': 'En attente', 'color': AppTheme.warning,  'icon': '⏳'},
  'approved': {'label': 'Approuvé',   'color': AppTheme.success,  'icon': '✅'},
  'rejected': {'label': 'Refusé',     'color': AppTheme.danger,   'icon': '❌'},
};

const _leaveTypes = [
  'Congés annuels', 'Congé maladie', 'Congé maternité/paternité',
  'Congé sans solde', 'Congé formation', 'Autre',
];

// ── Écran principal (routing selon rôle) ──────────────────────────────────────
class LeavesScreen extends StatelessWidget {
  const LeavesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (AuthService.isEmp) return const _MyLeavePlanScreen();
    return const _ManageLeavesScreen();
  }
}

// ── Mon planning de congés (Employé) ──────────────────────────────────────────
class _MyLeavePlanScreen extends StatefulWidget {
  const _MyLeavePlanScreen();
  @override State<_MyLeavePlanScreen> createState() => _MyLeavePlanScreenState();
}

class _MyLeavePlanScreenState extends State<_MyLeavePlanScreen> {
  Map<String, dynamic>? _planData;
  bool  _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getMyLeavePlan();
      setState(() { _planData = data as Map<String, dynamic>?; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Mes congés'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPeriodForm(),
          ),
        ],
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorWidget2(message: _error!, onRetry: _load)
        : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d           = _planData ?? {};
    final remaining   = d['remaining_days'] ?? 30;
    final plans       = (d['plans'] ?? []) as List;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        // ── KPIs ──────────────────────────────────────────────────────────
        const SectionTitle(title: 'MON SOLDE'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: StatCard(
              icon: '📅', value: '$remaining',
              label: 'Jours restants', color: AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(
              icon: '✅', value: '${d['approved_days'] ?? 0}',
              label: 'Jours approuvés', color: AppTheme.success)),
          ]),
        ),

        // ── Plans ─────────────────────────────────────────────────────────
        const SectionTitle(title: 'MES DEMANDES'),
        if (plans.isEmpty)
          const EmptyWidget(icon: '🏖️', title: 'Aucune demande de congé',
            subtitle: 'Appuyez sur + pour soumettre un planning')
        else
          ...plans.map((p) => _LeavePlanCard(
            plan: p as Map<String, dynamic>,
            onTap: () => _showPlanDetail(p),
          )),
        const SizedBox(height: 80),
      ]),
    );
  }

  void _showPlanDetail(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LeavePlanDetail(plan: plan),
    );
  }

  void _showAddPeriodForm() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddLeaveForm(onSubmitted: _load),
    );
  }
}

// ── Gestion congés (RH/DG) ────────────────────────────────────────────────────
class _ManageLeavesScreen extends StatefulWidget {
  const _ManageLeavesScreen();
  @override State<_ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<_ManageLeavesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _plans = [];
  bool  _loading = true;
  String? _error;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load({String? status}) async {
    setState(() { _loading = true; _error = null; _filter = status; });
    try {
      final raw = await ApiService.getLeavePlans(status: status);
      debugPrint('[LeavePlans] raw response type=${raw.runtimeType} value=$raw');
      List plans = [];
      if (raw is List) {
        plans = raw;
      } else if (raw is Map) {
        // Laravel pagination: {"data": [...]}
        if (raw['data'] is List) {
          plans = raw['data'] as List;
        }
        // Nested pagination: {"data": {"data": [...]}}
        else if (raw['data'] is Map && (raw['data'] as Map)['data'] is List) {
          plans = (raw['data'] as Map)['data'] as List;
        }
        // Named key variants
        else if (raw['leave_plans'] is List) {
          plans = raw['leave_plans'] as List;
        } else if (raw['plans'] is List) {
          plans = raw['plans'] as List;
        }
      }
      setState(() { _plans = plans; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approve(int id) async {
    try {
      await ApiService.approveLeavePlan(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planning approuvé ✅'),
          backgroundColor: AppTheme.success));
      await _load(status: _filter);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _reject(int id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter le planning'),
        content: TextField(controller: ctrl,
          decoration: const InputDecoration(labelText: 'Motif du rejet'),
          maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rejeter')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.rejectLeavePlan(id, ctrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planning refusé'),
          backgroundColor: AppTheme.danger));
      await _load(status: _filter);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Congés'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (i) {
            final filters = [null, 'pending', 'approved', 'rejected'];
            _load(status: filters[i]);
          },
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: '⏳ En attente'),
            Tab(text: '✅ Approuvés'),
            Tab(text: '❌ Refusés'),
          ],
        ),
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorWidget2(message: _error!, onRetry: () => _load(status: _filter))
        : _plans.isEmpty
          ? EmptyWidget(icon: '🏖️', title: 'Aucun planning de congé',
              subtitle: _filter != null ? 'Filtre: $_filter' : null)
          : RefreshIndicator(
              onRefresh: () => _load(status: _filter),
              child: ListView.builder(
                itemCount: _plans.length,
                itemBuilder: (_, i) {
                  final p      = _plans[i] as Map<String, dynamic>;
                  final status = p['status'] ?? 'pending';
                  final canAct = AuthService.isDG && status == 'pending';

                  return _LeavePlanCard(
                    plan: p,
                    showEmployee: true,
                    onTap: () => showModalBottomSheet(
                      context: context, isScrollControlled: true, useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _LeavePlanDetail(
                        plan: p,
                        onApprove: canAct ? () { Navigator.pop(context); _approve(p['id']); } : null,
                        onReject:  canAct ? () { Navigator.pop(context); _reject(p['id']);  } : null,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Carte planning ─────────────────────────────────────────────────────────────
class _LeavePlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool showEmployee;
  final VoidCallback onTap;
  const _LeavePlanCard({required this.plan, required this.onTap, this.showEmployee = false});

  @override
  Widget build(BuildContext context) {
    final p       = plan;
    final status  = p['status'] ?? 'pending';
    final cfg     = _leaveStatuses[status] ?? {'label': status, 'color': AppTheme.textMuted, 'icon': '•'};
    final color   = cfg['color'] as Color;
    final periods = (p['periods'] ?? []) as List;
    final days    = p['planned_days'] ?? 0;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(cfg['icon'] as String,
            style: const TextStyle(fontSize: 20)))),
        title: showEmployee
          ? Text(p['user']?['name'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))
          : Text('Planning ${p['year'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('$days jours · ${periods.length} période(s)',
          style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(cfg['label'] as String,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Détail planning ────────────────────────────────────────────────────────────
class _LeavePlanDetail extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _LeavePlanDetail({required this.plan, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final p       = plan;
    final periods = (p['periods'] ?? []) as List;
    final status  = p['status'] ?? 'pending';
    final cfg     = _leaveStatuses[status] ?? {'label': status, 'color': AppTheme.textMuted, 'icon': '•'};
    final color   = cfg['color'] as Color;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(
            p['user'] != null ? p['user']['name'] : 'Planning ${p['year']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${cfg['icon']} ${cfg['label']}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
        const Divider(height: 24),

        Expanded(child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow(icon: Icons.calendar_today, label: 'Année', value: '${p['year'] ?? '—'}'),
          InfoRow(icon: Icons.beach_access, label: 'Jours planifiés',
            value: '${p['planned_days'] ?? 0} jours'),

          const SizedBox(height: 12),
          const Text('PÉRIODES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: AppTheme.textMuted)),
          const SizedBox(height: 8),

          ...periods.map((per) {
            final pStatus = per['status'] ?? 'pending';
            final pCfg = _leaveStatuses[pStatus] ??
              {'label': pStatus, 'color': AppTheme.textMuted, 'icon': '•'};
            final pColor = pCfg['color'] as Color;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pColor.withOpacity(0.2))),
              child: Row(children: [
                Text(pCfg['icon'] as String, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_fmtDate(per['start_date'])} → ${_fmtDate(per['end_date'])}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${per['days'] ?? 0} jours · ${pCfg['label']}',
                    style: TextStyle(fontSize: 12, color: pColor)),
                ])),
              ]),
            );
          }),

          if (p['rejection_reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Motif du refus',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.danger,
                    fontSize: 12)),
                const SizedBox(height: 4),
                Text(p['rejection_reason'],
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ]),
            ),
          ],
        ]))),

        if (onApprove != null || onReject != null) ...[
          const Divider(),
          Row(children: [
            if (onReject != null)
              Expanded(child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close),
                label: const Text('Refuser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger)),
              )),
            if (onApprove != null && onReject != null) const SizedBox(width: 12),
            if (onApprove != null)
              Expanded(child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check),
                label: const Text('Approuver'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              )),
          ]),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ── Formulaire ajout congé (Employé) ──────────────────────────────────────────
class _AddLeaveForm extends StatefulWidget {
  final Function() onSubmitted;
  const _AddLeaveForm({required this.onSubmitted});
  @override State<_AddLeaveForm> createState() => _AddLeaveFormState();
}

class _AddLeaveFormState extends State<_AddLeaveForm> {
  final List<Map<String, dynamic>> _periods = [];
  final _reason = TextEditingController();
  int _year  = DateTime.now().year;
  bool _loading = false;
  String? _error;

  void _addPeriod() async {
    DateTime? start, end;
    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: const Text('Ajouter une période'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(start == null ? 'Date de début'
              : '${start!.day}/${start!.month}/${start!.year}'),
            onPressed: () async {
              final d = await showDatePicker(context: ctx,
                initialDate: DateTime.now(), firstDate: DateTime(2020),
                lastDate: DateTime(2100));
              if (d != null) setInner(() => start = d);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.event, size: 16),
            label: Text(end == null ? 'Date de fin'
              : '${end!.day}/${end!.month}/${end!.year}'),
            onPressed: () async {
              final d = await showDatePicker(context: ctx,
                initialDate: start ?? DateTime.now(), firstDate: DateTime(2020),
                lastDate: DateTime(2100));
              if (d != null) setInner(() => end = d);
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: start != null && end != null
              ? () {
                  setState(() => _periods.add({
                    'start_date': start!.toIso8601String().substring(0, 10),
                    'end_date':   end!.toIso8601String().substring(0, 10),
                    'days': end!.difference(start!).inDays + 1,
                  }));
                  Navigator.pop(ctx);
                }
              : null,
            child: const Text('Ajouter'),
          ),
        ],
      ),
    ));
  }

  Future<void> _submit() async {
    if (_periods.isEmpty) {
      setState(() => _error = 'Ajoutez au moins une période.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.createMyLeavePlan({
        'year':    _year,
        'reason':  _reason.text,
        'periods': _periods,
      });
      widget.onSubmitted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planning soumis !'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Demande de congé',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Année
        DropdownButtonFormField<int>(
          value: _year,
          decoration: const InputDecoration(labelText: 'Année'),
          items: [DateTime.now().year, DateTime.now().year + 1]
            .map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (v) => setState(() => _year = v ?? _year),
        ),
        const SizedBox(height: 12),

        // Périodes
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Périodes', style: TextStyle(fontWeight: FontWeight.w600)),
          TextButton.icon(
            onPressed: _addPeriod,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter'),
          ),
        ]),

        ..._periods.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
          child: Row(children: [
            Expanded(child: Text(
              '${p['start_date']} → ${p['end_date']} (${p['days']} jours)',
              style: const TextStyle(fontSize: 13))),
            IconButton(icon: const Icon(Icons.delete, size: 16, color: AppTheme.danger),
              onPressed: () => setState(() => _periods.remove(p))),
          ]),
        )),

        const SizedBox(height: 12),
        TextField(controller: _reason, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison / Commentaire')),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Soumettre la demande'),
        )),
      ])),
    );
  }
}
