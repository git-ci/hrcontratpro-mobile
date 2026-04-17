import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

const _reqTypes = {
  'salary_change': 'Révision salariale',
  'renewal':       'Renouvellement',
  'termination':   'Résiliation',
  'type_change':   'Changement de type',
};

const _reqStatuses = {
  'pending':  {'label': 'En attente', 'color': AppTheme.warning},
  'approved': {'label': 'Approuvée',  'color': AppTheme.success},
  'rejected': {'label': 'Rejetée',    'color': AppTheme.danger},
};

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _requests = [];
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
      final data = await ApiService.getRequests(status: status);
      setState(() {
        _requests = (data['data'] ?? []) as List;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approve(int id) async {
    try {
      await ApiService.approveRequest(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande approuvée ✅'),
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
        title: const Text('Rejeter la demande'),
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
      await ApiService.rejectRequest(id, ctrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande rejetée'),
          backgroundColor: AppTheme.danger));
      await _load(status: _filter);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  void _showDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RequestDetail(
        request: r,
        onApprove: AuthService.isDG && r['status'] == 'pending'
          ? () { Navigator.pop(context); _approve(r['id']); } : null,
        onReject: AuthService.isDG && r['status'] == 'pending'
          ? () { Navigator.pop(context); _reject(r['id']); } : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Demandes de contrat'),
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
            Tab(text: 'Toutes'),
            Tab(text: '⏳ En attente'),
            Tab(text: '✅ Approuvées'),
            Tab(text: '❌ Rejetées'),
          ],
        ),
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorWidget2(message: _error!, onRetry: _load)
        : _requests.isEmpty
          ? const EmptyWidget(icon: '📋', title: 'Aucune demande')
          : RefreshIndicator(
              onRefresh: () => _load(status: _filter),
              child: ListView.builder(
                itemCount: _requests.length,
                itemBuilder: (_, i) {
                  final r      = _requests[i] as Map<String, dynamic>;
                  final status = r['status'] ?? 'pending';
                  final cfg    = _reqStatuses[status] ??
                    {'label': status, 'color': AppTheme.textMuted};
                  final color  = cfg['color'] as Color;
                  final type   = _reqTypes[r['type']] ?? r['type'] ?? '—';

                  return Card(
                    child: ListTile(
                      onTap: () => _showDetail(r),
                      leading: Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.assignment_outlined, color: color)),
                      title: Text(type,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(r['requester']?['name'] ?? '—',
                        style: const TextStyle(fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                            child: Text(cfg['label'] as String,
                              style: TextStyle(color: color, fontSize: 11,
                                fontWeight: FontWeight.w600)),
                          ),
                          if (AuthService.isDG && status == 'pending') ...[
                            const SizedBox(height: 4),
                            const Text('Appuyer pour voir',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Détail demande ─────────────────────────────────────────────────────────────
class _RequestDetail extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestDetail({required this.request, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final r      = request;
    final status = r['status'] ?? 'pending';
    final cfg    = _reqStatuses[status] ?? {'label': status, 'color': AppTheme.textMuted};
    final color  = cfg['color'] as Color;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(_reqTypes[r['type']] ?? r['type'] ?? '—',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(cfg['label'] as String,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
        const Divider(height: 24),
        Expanded(child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow(icon: Icons.person, label: 'Demandé par',
            value: r['requester']?['name'] ?? '—'),
          InfoRow(icon: Icons.description, label: 'Contrat',
            value: r['contract']?['type']?.toString().toUpperCase() ?? '—'),
          if (r['proposed_salary'] != null)
            InfoRow(icon: Icons.euro, label: 'Salaire proposé',
              value: '${r['proposed_salary']}'),
          if (r['proposed_end_date'] != null)
            InfoRow(icon: Icons.event, label: 'Date fin proposée',
              value: r['proposed_end_date']),
          if (r['proposed_contract_type'] != null)
            InfoRow(icon: Icons.swap_horiz, label: 'Type proposé',
              value: r['proposed_contract_type'].toString().toUpperCase()),
          if (r['reason'] != null) ...[
            const SizedBox(height: 12),
            const Text('Raison', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
              child: Text(r['reason']),
            ),
          ],
          if (r['dg_comment'] != null) ...[
            const SizedBox(height: 12),
            const Text('Commentaire DG', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
              child: Text(r['dg_comment']),
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
                label: const Text('Rejeter'),
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
}
