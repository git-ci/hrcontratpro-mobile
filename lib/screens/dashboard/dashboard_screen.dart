import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  // Données supplémentaires pour les employés
  int _unreadCount   = 0;
  List<dynamic> _myPayslips  = [];
  List<dynamic> _myAttRecs   = [];
  Map<String, dynamic>? _myLeave;
  List<dynamic> _announcements = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await ApiService.getDashboard();

      int unread = 0;
      List<dynamic> payslips = [];
      List<dynamic> attRecs  = [];
      Map<String, dynamic>? leave;

      final announcements = await ApiService.getAnnouncements()
          .catchError((_) => <dynamic>[]);

      if (AuthService.isEmp) {
        final now = DateTime.now();
        final results = await Future.wait([
          ApiService.getUnreadCount().catchError((_) => 0),
          ApiService.getMyPayslips().catchError((_) => <dynamic>[]),
          ApiService.getMyAttendance(
            params: '?month=${now.month}&year=${now.year}',
          ).catchError((_) => <String, dynamic>{}),
          ApiService.getMyLeavePlan().catchError((_) => <String, dynamic>{}),
        ]);
        unread   = (results[0] as int?) ?? 0;
        payslips = (results[1] as List<dynamic>?) ?? [];
        final attMap = results[2] as Map<String, dynamic>? ?? {};
        attRecs  = (attMap['data'] as List<dynamic>?) ?? [];
        leave    = results[3] as Map<String, dynamic>?;
      } else {
        unread = await ApiService.getUnreadCount().catchError((_) => 0);
      }

      setState(() {
        _stats         = s;
        _unreadCount   = unread;
        _myPayslips    = payslips;
        _myAttRecs     = attRecs;
        _myLeave       = leave;
        _announcements = announcements;
        _loading       = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user   = AuthService.user;
    final name   = user?['name'] ?? '';
    final role   = AuthService.role ?? 'employee';
    final prefix = role == 'employee' ? 'emp' : role;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tableau de bord',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Bonjour, ${name.split(' ').first}',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        ]),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        actions: [
          const DrawerMenuButton(),
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
              backgroundColor: AppTheme.danger,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go('/$prefix/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingWidget(message: 'Chargement…')
            : _error != null
                ? ErrorWidget2(message: _error!, onRetry: _load)
                : _buildContent(prefix),
      ),
    );
  }

  Widget _buildContent(String prefix) {
    final s    = _stats ?? {};
    final role = AuthService.role ?? 'employee';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── KPIs principaux (DG / RH) ────────────────────────────────────────
        if (role != 'employee') ...[
          const SectionTitle(title: "VUE D'ENSEMBLE"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
              children: [
                StatCard(icon: '👥', value: '${s['total_employees'] ?? 0}',
                    label: 'Employés', color: AppTheme.primary,
                    onTap: () => context.go('/$prefix/employees')),
                StatCard(icon: '📄', value: '${s['active_contracts'] ?? 0}',
                    label: 'Contrats actifs', color: AppTheme.success,
                    onTap: () => context.go('/$prefix/contracts')),
                StatCard(icon: '⏳', value: '${s['pending_requests'] ?? 0}',
                    label: 'Demandes en attente', color: AppTheme.warning,
                    onTap: () => context.go('/$prefix/requests')),
                StatCard(icon: '⚠️', value: '${s['expiring_soon'] ?? 0}',
                    label: 'Expirent bientôt', color: AppTheme.danger,
                    onTap: () => context.go('/$prefix/contracts')),
              ],
            ),
          ),
        ],

        // ── Présence & Absentéisme (DG / RH) ────────────────────────────────
        if (s['attendance'] is Map) ...[
          const SectionTitle(title: 'PRÉSENCE & ABSENTÉISME'),
          Builder(builder: (_) {
            final att = Map<String, dynamic>.from(s['attendance'] as Map);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _AttKpi(icon: '✅',
                      value: '${att['presence_rate'] ?? '—'}%',
                      label: 'Taux présence',
                      sub: '${att['present_count'] ?? 0} présences',
                      color: AppTheme.success)),
                  const SizedBox(width: 10),
                  Expanded(child: _AttKpi(icon: '❌',
                      value: '${att['absence_rate'] ?? '—'}%',
                      label: 'Absentéisme',
                      sub: '${att['absent_count'] ?? 0} absences',
                      color: AppTheme.danger)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _AttKpi(icon: '📅',
                      value: '${att['total_days_worked'] ?? '—'}',
                      label: 'Jours travaillés',
                      sub: '${att['working_days'] ?? 0} ouvrables',
                      color: AppTheme.info)),
                  const SizedBox(width: 10),
                  Expanded(child: _AttKpi(icon: '⏳',
                      value: '${att['total_hours_worked'] ?? '—'}',
                      label: 'Heures travaillées',
                      sub: '≈ 8h/jour',
                      color: const Color(0xFF862e9c))),
                  const SizedBox(width: 10),
                  Expanded(child: _AttKpi(icon: '⚠️',
                      value: '${att['unjustified_count'] ?? '—'}',
                      label: 'Abs. non just.',
                      sub: 'Sans justif.',
                      color: AppTheme.warning)),
                ]),
              ]),
            );
          }),
        ],

        // ── Masse salariale (DG) ─────────────────────────────────────────────
        if (role == 'dg' && s['salary'] is Map) ...[
          const SectionTitle(title: 'MASSE SALARIALE'),
          Builder(builder: (_) {
            final sal = Map<String, dynamic>.from(s['salary'] as Map);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _SalaryKpi(
                    label: 'Masse mensuelle',
                    value: '${_fmtSalary(sal['total_monthly'])} XOF')),
                const SizedBox(width: 10),
                Expanded(child: _SalaryKpi(
                    label: 'Moy. mensuelle',
                    value: '${_fmtSalary(sal['avg_monthly'])} XOF')),
              ]),
            );
          }),
        ],

        // ── Contrats par type ────────────────────────────────────────────────
        if (role != 'employee') ...[
          const SectionTitle(title: 'CONTRATS PAR TYPE'),
          _buildContractChart(s['contracts_by_type']),
        ],

        // ── Demandes récentes ────────────────────────────────────────────────
        if (role != 'employee' &&
            s['recent_requests'] is List &&
            (s['recent_requests'] as List).isNotEmpty) ...[
          SectionTitle(title: 'DEMANDES RÉCENTES',
              action: TextButton(
                  onPressed: () => context.go('/$prefix/requests'),
                  child: const Text('Voir tout'))),
          ...(s['recent_requests'] as List).take(3).map((item) {
            if (item is! Map) return const SizedBox.shrink();
            final r      = Map<String, dynamic>.from(item);
            final status = r['status'] ?? 'pending';
            final color  = status == 'pending' ? AppTheme.warning
                : status == 'approved' ? AppTheme.success : AppTheme.danger;
            final user   = r['requester'] ??
                (r['contract'] is Map ? (r['contract'] as Map)['user'] : null);
            final uname  = user is Map ? (user['name'] ?? '—') : '—';
            return Card(
              child: ListTile(
                leading: Icon(Icons.assignment_outlined, color: color),
                title: Text(uname.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(_fmtType(r['type']?.toString()),
                    style: const TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    status == 'pending' ? 'En attente'
                        : status == 'approved' ? 'Approuvée' : 'Rejetée',
                    style: TextStyle(color: color, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
        ],

        // ── Contrats expirant ────────────────────────────────────────────────
        if (s['expiring_contracts'] is List &&
            (s['expiring_contracts'] as List).isNotEmpty) ...[
          SectionTitle(title: 'EXPIRATIONS IMMINENTES',
              action: TextButton(
                  onPressed: () => context.go('/$prefix/contracts'),
                  child: const Text('Voir tout'))),
          ...(s['expiring_contracts'] as List).take(3).map((item) {
            if (item is! Map) return const SizedBox.shrink();
            final c    = Map<String, dynamic>.from(item);
            final user = c['user'];
            final name = user is Map ? (user['name'] ?? '—') : '—';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: AppTheme.warning),
                title: Text(name.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                    '${c['type']?.toString().toUpperCase() ?? '—'} · expire le ${_fmtDate(c['end_date']?.toString())}',
                    style: const TextStyle(fontSize: 12)),
              ),
            );
          }),
        ],

        // ── Accès rapides (Employé) ──────────────────────────────────────────
        if (role == 'employee') ...[
          const SectionTitle(title: 'ACCÈS RAPIDES'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _QuickActionTile(
                  icon: Icons.qr_code_scanner,
                  label: 'Scanner un QR',
                  subtitle: 'Pointer ma présence',
                  onTap: () => context.go('/emp/scan')),
              _QuickActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Mes bulletins',
                  subtitle: 'Consulter mes bulletins de salaire',
                  onTap: () => context.go('/emp/payslips')),
              _QuickActionTile(
                  icon: Icons.beach_access,
                  label: 'Mes congés',
                  subtitle: 'Voir mon planning',
                  onTap: () => context.go('/emp/leaves')),
              _QuickActionTile(
                  icon: Icons.description,
                  label: 'Mes contrats',
                  subtitle: 'Voir mes contrats',
                  onTap: () => context.go('/emp/contracts')),
              _QuickActionTile(
                  icon: Icons.schedule,
                  label: 'Mon pointage',
                  subtitle: 'Historique de présence',
                  onTap: () => context.go('/emp/attendance')),
            ]),
          ),

          // ── Annonces ──────────────────────────────────────────────────────
          if (_announcements.isNotEmpty) ...[
            const SectionTitle(title: 'ANNONCES'),
            ..._announcements.take(3).map((a) =>
                _DashboardAnnouncementCard(ann: a as Map<String, dynamic>)),
          ],

          // ── Statistiques personnelles ──────────────────────────────────────
          const SectionTitle(title: 'MES STATISTIQUES DU MOIS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildEmpStats(s),
          ),
        ],

        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildEmpStats(Map<String, dynamic> s) {
    // Pointage du mois
    final present = _myAttRecs
        .where((r) => r is Map && (r['status'] == 'present' || r['status'] == 'mission'))
        .length;
    final absent = _myAttRecs
        .where((r) => r is Map && r['status'] != 'present' && r['status'] != 'mission')
        .length;
    final total  = _myAttRecs.length;

    // Contrat actif
    final contract = s['active_contract'] as Map<String, dynamic>?;
    final ctType   = contract?['type']?.toString().toUpperCase() ?? '—';
    final ctEnd    = _fmtDate(contract?['end_date']?.toString());
    final ctSalary = contract != null ? _fmtSalary(contract['salary']) : null;

    // Congés
    final totalRight  = (_myLeave?['total_right'] as num?)?.toInt() ?? 30;
    final planned     = (_myLeave?['already_planned'] as num?)?.toInt() ?? 0;
    final remaining   = totalRight - planned;
    final leavePlan   = _myLeave?['plan'] as Map<String, dynamic>?;
    final leaveStatus = leavePlan?['status'] as String?;

    final leaveStart  = leavePlan?['first_start_date'] as String?;
    final leaveReturn = leavePlan?['return_date'] as String?;
    final leavePeriods = leavePlan?['periods'] as List<dynamic>? ?? [];

    // Bulletins
    final payslipCount = _myPayslips.length;

    return Column(children: [
      // Pointage
      _EmpStatCard(
        icon: Icons.schedule_outlined,
        title: 'Pointage ce mois',
        color: AppTheme.info,
        child: Row(children: [
          _MiniKpi(value: '$present', label: 'Présences', color: AppTheme.success),
          const SizedBox(width: 8),
          _MiniKpi(value: '$absent', label: 'Absences', color: AppTheme.danger),
          const SizedBox(width: 8),
          _MiniKpi(value: '${(present * 8)}h', label: 'Heures', color: AppTheme.info),
          if (total > 0) ...[
            const SizedBox(width: 8),
            _MiniKpi(
              value: '${(present / total * 100).toStringAsFixed(0)}%',
              label: 'Présence',
              color: AppTheme.primary,
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),

      // Congés
      _EmpStatCard(
        icon: Icons.beach_access_outlined,
        title: 'Mes congés',
        color: AppTheme.warning,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // KPIs
          _MiniKpi(value: '$totalRight', label: 'Droit total', color: AppTheme.textMuted),
          const SizedBox(width: 8),
          _MiniKpi(value: '$planned', label: 'Planifiés', color: AppTheme.warning),
          const SizedBox(width: 8),
          _MiniKpi(value: '$remaining', label: 'Restants', color: AppTheme.success),
          // Détails plan
          const SizedBox(width: 10),
          Container(width: 1, height: 48, color: AppTheme.border),
          const SizedBox(width: 10),
          if (leavePlan != null)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _LeaveStatusChip(status: leaveStatus ?? ''),
                const SizedBox(height: 4),
                if (leavePeriods.isNotEmpty)
                  ...leavePeriods.map((p) {
                    final period = p as Map<String, dynamic>;
                    return Text(
                      '${_fmtDate(period['start'] as String?)} → ${_fmtDate(period['end'] as String?)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    );
                  })
                else if (leaveStart != null)
                  Text(_fmtDate(leaveStart),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                if (leaveReturn != null)
                  Text('Reprise : ${_fmtDate(leaveReturn)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ]),
            )
          else
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Aucun planning pour cette année',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    maxLines: 2, softWrap: true),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.go('/emp/leaves'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                    ),
                    child: const Text('Planifier →',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppTheme.warning)),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),

      // Contrat + bulletins
      Row(children: [
        Expanded(
          child: _EmpStatCard(
            icon: Icons.description_outlined,
            title: 'Mon contrat',
            color: AppTheme.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctType,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
              if (ctEnd != '—')
                Text('Expire : $ctEnd',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              if (ctSalary != null)
                Text('$ctSalary XOF/mois',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.go('/emp/payslips'),
            child: _EmpStatCard(
              icon: Icons.receipt_long_outlined,
              title: 'Bulletins',
              color: const Color(0xFF862e9c),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$payslipCount',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: Color.fromARGB(255, 134, 46, 156))),
                const Text('bulletin(s) reçu(s)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildContractChart(dynamic raw) {
    Map<String, double> data = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
        if (n > 0) data[k.toString().toUpperCase()] = n;
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final k = item['type']?.toString().toUpperCase() ?? '?';
          final v = item['count'] ?? item['value'] ?? 0;
          final n = v is num ? v.toDouble() : 0.0;
          if (n > 0) data[k] = n;
        }
      }
    }
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: EmptyWidget(icon: '📄', title: 'Aucun contrat'),
      );
    }
    final colors = [AppTheme.primary, AppTheme.accent, AppTheme.success,
        AppTheme.warning, AppTheme.danger];
    final entries = data.entries.toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      height: 200,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sections: entries.asMap().entries.map((e) {
              final i = e.key; final entry = e.value;
              return PieChartSectionData(value: entry.value,
                  title: '${entry.value.toInt()}',
                  color: colors[i % colors.length], radius: 55,
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white,
                      fontWeight: FontWeight.w700));
            }).toList(),
            sectionsSpace: 2, centerSpaceRadius: 35)),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final i = e.key; final entry = e.value;
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(entry.key, style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w500)),
                  ]));
            }).toList()),
      ]),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return d; }
  }

  String _fmtSalary(dynamic val) {
    if (val == null) return '—';
    final n = val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toStringAsFixed(0);
  }

  String _fmtType(String? t) {
    switch (t) {
      case 'salary_change': return 'Révision salariale';
      case 'renewal':       return 'Renouvellement';
      case 'termination':   return 'Résiliation';
      case 'type_change':   return 'Changement de type';
      default:              return t ?? '—';
    }
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _AttKpi extends StatelessWidget {
  final String icon, value, label, sub;
  final Color color;
  const _AttKpi({required this.icon, required this.value, required this.label,
      required this.sub, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted,
          fontWeight: FontWeight.w600)),
      Text(sub, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
    ]),
  );
}

class _SalaryKpi extends StatelessWidget {
  final String label, value;
  const _SalaryKpi({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: AppTheme.primary)),
    ]),
  );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _QuickActionTile({required this.icon, required this.label,
      required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppTheme.primary)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
      onTap: onTap,
    ),
  );
}

class _EmpStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const _EmpStatCard({required this.icon, required this.title,
      required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.3)),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _MiniKpi extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniKpi({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
    ],
  );
}

class _LeaveStatusChip extends StatelessWidget {
  final String status;
  const _LeaveStatusChip({required this.status});

  static const _cfg = {
    'approved'        : (Color(0xFF1B8A4E), Color(0xFFE8F5EE), '✅'),
    'pending'         : (Color(0xFFB45309), Color(0xFFFEF3C7), '⏳'),
    'draft'           : (Color(0xFF6B7280), Color(0xFFF3F4F6), '📝'),
    'rejected'        : (Color(0xFFDC2626), Color(0xFFFEE2E2), '❌'),
    'change_requested': (Color(0xFFD97706), Color(0xFFFEF3C7), '🔄'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg[status] ?? (AppTheme.textMuted, AppTheme.border, '📋');
    final fg  = cfg.$1;
    final bg  = cfg.$2;
    final ic  = cfg.$3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(ic, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Text(status == 'approved' ? 'Approuvé'
            : status == 'pending'  ? 'En attente'
            : status == 'draft'    ? 'Brouillon'
            : status == 'rejected' ? 'Rejeté'
            : status == 'change_requested' ? 'À modifier'
            : status,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

class _DashboardAnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> ann;
  const _DashboardAnnouncementCard({required this.ann});

  static const _cfg = {
    'info'    : (Color(0xFF1565C0), Color(0xFFE3F2FD), Icons.info_outline),
    'warning' : (Color(0xFFE65100), Color(0xFFFFF3E0), Icons.warning_amber_outlined),
    'sanction': (Color(0xFFC62828), Color(0xFFFFEBEE), Icons.gavel_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final type = ann['type'] as String? ?? 'info';
    final cfg  = _cfg[type] ?? _cfg['info']!;
    final fg   = cfg.$1;
    final bg   = cfg.$2;
    final icon = cfg.$3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ann['title'] ?? '',
              style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 13)),
          const SizedBox(height: 2),
          Text(ann['body'] ?? '',
              style: TextStyle(fontSize: 12, color: fg.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(ann['sender']?['name'] ?? '',
              style: TextStyle(fontSize: 10, color: fg.withOpacity(0.6))),
        ])),
      ]),
    );
  }
}
