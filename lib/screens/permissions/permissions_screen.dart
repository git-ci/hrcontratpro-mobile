import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';

// ── Labels ────────────────────────────────────────────────────────────────────

const _typeLabels = {
  'conge_exceptionnel':  'Congé exceptionnel',
  'autorisation_absence': "Autorisation d'absence",
};

const _periodeLabels = {
  'matin':      'Matin',
  'apres_midi': 'Après-midi',
  'journee':    'Journée entière',
};

const _subtypeLabels = {
  'maladie_ordinaire':       'Maladie ordinaire',
  'maternite':               'Congé de maternité',
  'paternite':               'Congé de paternité',
  'grossesse_pathologique':  'Grossesse pathologique',
  'couches_pathologiques':   'Couches pathologiques',
  'accident_service':        'Accident de service',
  'autre':                   'Autres (à préciser)',
};

const _statusLabels = {
  'pending_manager':        'Attente responsable',
  'pending_dg':             'Attente DG',
  'approved':               'Accordé',
  'refused':                'Refusé',
  'modification_requested': 'Modification requise',
};

const _statusColors = {
  'pending_manager':        AppTheme.warning,
  'pending_dg':             Colors.orange,
  'approved':               AppTheme.success,
  'refused':                AppTheme.danger,
  'modification_requested': Colors.purple,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String? _filter;
  bool _myOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? status, bool? myOnly}) async {
    final resolvedMyOnly = myOnly ?? _myOnly;
    setState(() { _loading = true; _error = null; _filter = status; _myOnly = resolvedMyOnly; });
    try {
      final myId = resolvedMyOnly ? (AuthService.user?['id'] as int?) : null;
      final data = await ApiService.getPermissionRequests(status: status, userId: myId);
      final raw = data['data'];
      setState(() {
        _items   = raw is List ? List<dynamic>.from(raw) : [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.isDG || AuthService.isRH;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de permission'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => ShellScope.maybeOf(ctx)?.openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(status: _filter),
          ),
        ],
      ),
      drawer: AppDrawer(role: AuthService.role ?? 'emp'),
      floatingActionButton: !AuthService.isDG
          ? FloatingActionButton.extended(
              onPressed: _showCreateForm,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle demande'),
            )
          : null,
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
                    : _items.isEmpty
                        ? _buildEmpty(isAdmin)
                        : RefreshIndicator(
                            onRefresh: () => _load(status: _filter),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (_, i) => _buildCard(_items[i], isAdmin),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = <String?>[null, 'pending_manager', 'pending_dg', 'approved', 'refused'];
    final labels  = ['Toutes', 'Attente resp.', 'Attente DG', 'Accordées', 'Refusées'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Chip "Mes demandes" visible uniquement pour le RH
          if (AuthService.isRH) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Mes demandes', style: TextStyle(fontSize: 12)),
                selected: _myOnly,
                onSelected: (_) => _load(status: _filter, myOnly: !_myOnly),
                selectedColor: AppTheme.rhColor.withOpacity(0.15),
                checkmarkColor: AppTheme.rhColor,
              ),
            ),
            Container(width: 1, height: 20, color: Colors.grey[300], margin: const EdgeInsets.only(right: 8)),
          ],
          ...List.generate(filters.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i], style: const TextStyle(fontSize: 12)),
              selected: _filter == filters[i] && !_myOnly,
              onSelected: (_) => _load(status: filters[i], myOnly: false),
              selectedColor: AppTheme.primary.withOpacity(0.15),
              checkmarkColor: AppTheme.primary,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isAdmin) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textMuted),
      const SizedBox(height: 12),
      const Text('Aucune demande de permission',
          style: TextStyle(color: AppTheme.textMuted)),
      if (!AuthService.isDG) ...[
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showCreateForm,
          icon: const Icon(Icons.add),
          label: const Text('Soumettre une demande'),
        ),
      ],
    ]),
  );

  Widget _buildCard(Map<String, dynamic> r, bool isAdmin) {
    final status      = r['status'] as String? ?? '';
    final type        = r['type'] as String? ?? '';
    final isConge     = type == 'conge_exceptionnel';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final myIdStr     = AuthService.user?['id']?.toString();
    final isSubordinate = r['manager_id']?.toString() == myIdStr &&
        r['user_id']?.toString() != myIdStr;
    final isMySubordinate = isSubordinate && status == 'pending_manager';
    final isDGRole    = AuthService.isDG;
    final canEditDelete = myIdStr != null &&
        r['user_id']?.toString() == myIdStr &&
        (status == 'pending_manager' ||
         (status == 'pending_dg' && r['manager_decision'] == null));

    final periodeText = isConge
        ? '${_fmt(r['date_debut'])} → ${_fmt(r['date_fin'])}'
        : '${_fmt(r['date_depart'])} → ${_fmt(r['date_reprise'])}'
          '  ·  ${r['duree_valeur']}${r['duree_unite'] == 'heure' ? ' h' : ' j'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                (isAdmin || isSubordinate)
                    ? (r['user']?['name'] as String? ?? '—')
                    : (_typeLabels[type] ?? type),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabels[status] ?? status,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            if (canEditDelete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'edit')   _showEditForm(r);
                  if (v == 'delete') _deleteRequest(r['id'] as int);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Text('Modifier'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      SizedBox(width: 10),
                      Text('Supprimer', style: TextStyle(color: AppTheme.danger)),
                    ]),
                  ),
                ],
              ),
          ]),
          const SizedBox(height: 6),
          if (isAdmin)
            Text(_typeLabels[type] ?? type,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(periodeText,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showDetail(r, isMySubordinate, isDGRole),
                child: const Text('Détails'),
              ),
            ),
            if (status == 'approved' && isAdmin) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openDocument(r['id'] as int),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Document'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ],
            if (status == 'modification_requested' && !isAdmin) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showResubmitForm(r),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Re-soumettre'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Future<void> _showDetail(Map<String, dynamic> r, bool isMySubordinate, bool isDGRole) async {
    Map<String, dynamic> full;
    try {
      full = await ApiService.getPermissionRequest(r['id'] as int);
    } catch (_) {
      full = r;
    }
    if (!mounted) return;

    final status  = full['status'] as String? ?? '';
    final isConge = full['type'] == 'conge_exceptionnel';
    final myIdStr = AuthService.user?['id']?.toString();
    final canEditDelete = myIdStr != null &&
        full['user_id']?.toString() == myIdStr &&
        (status == 'pending_manager' ||
         (status == 'pending_dg' && full['manager_decision'] == null));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Demande de permission',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _detailRow('Employé', full['user']?['name'] ?? '—'),
            _detailRow('Responsable', full['manager']?['name'] ?? '— DG —'),
            _detailRow('Type', _typeLabels[full['type']] ?? full['type'] ?? '—'),
            if (isConge && full['conge_subtype'] != null)
              _detailRow('Précision', _subtypeLabels[full['conge_subtype']] ?? full['conge_subtype']),
            if (isConge) ...[
              _detailRow('Date de début', _fmt(full['date_debut'])),
              _detailRow('Date de fin', _fmt(full['date_fin'])),
            ] else ...[
              _detailRow('Période', _periodeLabels[full['periode']] ?? full['periode'] ?? '—'),
              _detailRow('Durée', '${full['duree_valeur']} ${full['duree_unite'] == 'heure' ? 'heure(s)' : 'jour(s)'}'),
              _detailRow('Date de départ', _fmt(full['date_depart'])),
              _detailRow('Date de reprise', _fmt(full['date_reprise'])),
            ],
            if ((full['motif'] as String?)?.isNotEmpty == true)
              _detailRow('Motif', full['motif']),
            if (full['justificatif_url'] != null)
              _justificatifButton(full['justificatif_url'] as String),
            _detailRow('Statut', _statusLabels[status] ?? status),
            if (full['manager_decision'] != null) ...[
              const Divider(height: 24),
              const Text('Décision responsable',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _detailRow('Décision',
                  full['manager_decision'] == 'approved' ? '✅ Validé' : '❌ Refusé'),
              if ((full['manager_comment'] as String?)?.isNotEmpty == true)
                _detailRow('Commentaire', full['manager_comment']),
            ],
            if (full['dg_decision'] != null) ...[
              const Divider(height: 24),
              const Text('Décision DG',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _detailRow('Décision', full['dg_decision'] == 'approved'
                  ? '✅ Accordé'
                  : full['dg_decision'] == 'refused' ? '❌ Refusé' : '✏️ Modification'),
              if ((full['dg_comment'] as String?)?.isNotEmpty == true)
                _detailRow('Commentaire', full['dg_comment']),
            ],
            const SizedBox(height: 20),
            if (status == 'approved' && (AuthService.isDG || AuthService.isRH))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openDocument(full['id'] as int),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Voir l'autorisation"),
                ),
              ),
            if (status == 'approved' && AuthService.isEmp)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD3F9D8),
                  border: Border.all(color: const Color(0xFF8CE99A)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('📋', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Votre autorisation est prête',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1E7B34))),
                      SizedBox(height: 4),
                      Text(
                        'Votre demande a été accordée par le DG. '
                        'Veuillez vous rendre au service RH pour récupérer votre document d\'autorisation.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF2B8A3E), height: 1.4),
                      ),
                    ]),
                  ),
                ]),
              ),
            if (status == 'modification_requested' && !AuthService.isDG)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); _showResubmitForm(full); },
                  icon: const Icon(Icons.edit),
                  label: const Text('Re-soumettre la demande'),
                ),
              ),
            if (canEditDelete) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); _showEditForm(full); },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () { Navigator.pop(context); _deleteRequest(full['id'] as int); },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                )),
              ]),
            ],
            if (isMySubordinate && status == 'pending_manager') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  onPressed: () { Navigator.pop(context); _managerDecide(full['id'] as int, 'approved'); },
                  child: const Text('✓ Valider'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () { Navigator.pop(context); _managerDecide(full['id'] as int, 'refused'); },
                  child: const Text('✕ Refuser'),
                )),
              ]),
            ],
            if (isDGRole && status == 'pending_dg') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  onPressed: () { Navigator.pop(context); _dgDecide(full['id'] as int, 'approved'); },
                  child: const Text('✓ Accorder'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () { Navigator.pop(context); _dgDecide(full['id'] as int, 'refused'); },
                  child: const Text('✕ Refuser'),
                )),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () { Navigator.pop(context); _dgDecide(full['id'] as int, 'modification_requested'); },
                child: const Text('✏️ Demander une modification'),
              )),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _justificatifButton(String url) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(
        width: 120,
        child: Text('Justificatif',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ),
      Expanded(
        child: GestureDetector(
          onTap: () => _openJustificatif(url),
          child: const Text('📎 Voir le justificatif joint',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary,
                  decoration: TextDecoration.underline)),
        ),
      ),
    ]),
  );

  void _openJustificatif(String url) {
    final lower = url.toLowerCase().split('?').first;
    final isImage = lower.endsWith('.jpg')  ||
                    lower.endsWith('.jpeg') ||
                    lower.endsWith('.png')  ||
                    lower.endsWith('.gif');
    if (isImage) {
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Impossible de charger l\'image',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ]),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _detailRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 120,
        child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ),
      Expanded(child: Text(value?.toString() ?? '—',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  // ── Create / Resubmit form ─────────────────────────────────────────────────

  void _showCreateForm({Map<String, dynamic>? defaults, int? resubmitId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PermissionForm(
        defaults: defaults,
        resubmitId: resubmitId,
        onSubmitted: () => _load(status: _filter),
      ),
    );
  }

  void _showResubmitForm(Map<String, dynamic> r) {
    _showCreateForm(defaults: r, resubmitId: r['id'] as int);
  }

  void _showEditForm(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PermissionForm(
        defaults: r,
        editId: r['id'] as int,
        onSubmitted: () => _load(status: _filter),
      ),
    );
  }

  Future<void> _deleteRequest(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Supprimer la demande'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer cette demande ? Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deletePermissionRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Demande supprimée'),
            backgroundColor: AppTheme.success));
        _load(status: _filter);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  // ── Decisions ──────────────────────────────────────────────────────────────

  Future<void> _managerDecide(int id, String decision) async {
    final commentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(decision == 'approved' ? 'Valider la demande' : 'Refuser la demande'),
        content: TextField(
          controller: commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: decision == 'refused' ? 'Motif (obligatoire)' : 'Commentaire (optionnel)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.managerDecidePermission(id, {
        'decision': decision,
        'comment': commentCtrl.text,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décision enregistrée ✅'), backgroundColor: AppTheme.success));
      _load(status: _filter);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _dgDecide(int id, String decision) async {
    final commentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text({
          'approved': 'Accorder la permission',
          'refused':  'Refuser la demande',
          'modification_requested': 'Demander une modification',
        }[decision] ?? 'Décision'),
        content: TextField(
          controller: commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: decision != 'approved' ? 'Commentaire (obligatoire)' : 'Commentaire (optionnel)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.dgDecidePermission(id, {
        'decision': decision,
        'comment': commentCtrl.text,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décision enregistrée ✅'), backgroundColor: AppTheme.success));
      _load(status: _filter);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _openDocument(int id) async {
    try {
      final html = await ApiService.getPermissionDocument(id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _DocumentScreen(html: html)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  static String _fmt(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return d.toString(); }
  }
}

// ── Create / Resubmit form widget ─────────────────────────────────────────────

class _PermissionForm extends StatefulWidget {
  final Map<String, dynamic>? defaults;
  final int? resubmitId;
  final int? editId;
  final VoidCallback onSubmitted;

  const _PermissionForm({this.defaults, this.resubmitId, this.editId, required this.onSubmitted});

  @override
  State<_PermissionForm> createState() => _PermissionFormState();
}

class _PermissionFormState extends State<_PermissionForm> {
  String  _type        = 'conge_exceptionnel';
  String? _subtype;
  String  _periode     = 'journee';
  double  _dureeValeur = 1.0;
  String  _dureeUnite  = 'jour';
  DateTime? _debut;
  DateTime? _fin;
  DateTime? _depart;
  DateTime? _reprise;
  final _motifCtrl = TextEditingController();
  File?   _justificatif;
  String? _justificatifName;
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.defaults;
    if (d != null) {
      _type        = d['type'] as String? ?? 'conge_exceptionnel';
      _subtype     = d['conge_subtype'] as String?;
      _periode     = d['periode'] as String? ?? 'journee';
      _dureeValeur = ((d['duree_valeur'] as num?) ?? 1.0).toDouble();
      _dureeUnite  = d['duree_unite'] as String? ?? 'jour';
      if (d['date_debut']  != null) try { _debut   = DateTime.parse(d['date_debut']);  } catch (_) {}
      if (d['date_fin']    != null) try { _fin     = DateTime.parse(d['date_fin']);    } catch (_) {}
      if (d['date_depart'] != null) try { _depart  = DateTime.parse(d['date_depart']); } catch (_) {}
      if (d['date_reprise']!= null) try { _reprise = DateTime.parse(d['date_reprise']);} catch (_) {}
      _motifCtrl.text = d['motif'] as String? ?? '';
    }
  }

  @override
  void dispose() { _motifCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _justificatif     = File(result.files.single.path!);
        _justificatifName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    final isConge = _type == 'conge_exceptionnel';
    if (isConge) {
      if (_debut == null || _fin == null) {
        setState(() => _error = 'Les dates de début et de fin sont obligatoires.');
        return;
      }
    } else {
      if (_depart == null || _reprise == null) {
        setState(() => _error = 'Les dates de départ et de reprise sont obligatoires.');
        return;
      }
    }
    setState(() { _loading = true; _error = null; });

    final fmt = (DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'type':  _type,
      'motif': _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim(),
    };

    if (isConge) {
      if (_subtype != null && _subtype!.isNotEmpty) payload['conge_subtype'] = _subtype;
      payload['date_debut'] = fmt(_debut!);
      payload['date_fin']   = fmt(_fin!);
    } else {
      payload['periode']      = _periode;
      payload['duree_valeur'] = _dureeValeur;
      payload['duree_unite']  = _dureeUnite;
      payload['date_depart']  = fmt(_depart!);
      payload['date_reprise'] = fmt(_reprise!);
    }

    try {
      if (widget.editId != null) {
        await ApiService.updatePermissionRequest(widget.editId!, payload,
            justificatif: _justificatif);
      } else if (widget.resubmitId != null) {
        await ApiService.resubmitPermissionRequest(widget.resubmitId!, payload,
            justificatif: _justificatif);
      } else {
        await ApiService.createPermissionRequest(payload,
            justificatif: _justificatif);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.editId != null
              ? 'Demande modifiée ✅'
              : 'Demande soumise avec succès ✅'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static const _subtypeOptions = {
    'maladie_ordinaire':       'Maladie ordinaire',
    'maternite':               'Congé de maternité',
    'paternite':               'Congé de paternité',
    'grossesse_pathologique':  'Grossesse pathologique',
    'couches_pathologiques':   'Couches pathologiques',
    'accident_service':        'Accident de service',
    'autre':                   'Autres (à préciser)',
  };

  @override
  Widget build(BuildContext context) {
    final isEdit     = widget.editId != null;
    final isResubmit = widget.resubmitId != null;
    final dgComment  = widget.defaults?['dg_comment'] as String?;
    final isConge    = _type == 'conge_exceptionnel';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text(isEdit ? 'Modifier la demande' : isResubmit ? 'Re-soumettre la demande' : 'Nouvelle demande de permission',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (dgComment != null && dgComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Text('💬 DG : $dgComment',
                  style: const TextStyle(fontSize: 13, color: Colors.deepOrange)),
            ),
          ],
          const SizedBox(height: 16),

          // ── Type ──────────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type *'),
            items: const [
              DropdownMenuItem(value: 'conge_exceptionnel',  child: Text('Congé exceptionnel')),
              DropdownMenuItem(value: 'autorisation_absence', child: Text("Autorisation d'absence")),
            ],
            onChanged: (v) => setState(() { _type = v!; _subtype = null; }),
          ),
          const SizedBox(height: 12),

          // ── Précision (Congé exceptionnel uniquement) ─────────────────────
          if (isConge) ...[
            DropdownButtonFormField<String>(
              value: _subtypeOptions.containsKey(_subtype) ? _subtype : null,
              decoration: const InputDecoration(labelText: 'Précision *'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Sélectionner —')),
                ..._subtypeOptions.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: (v) => setState(() => _subtype = v),
            ),
            const SizedBox(height: 12),
          ],

          // ── Section Période ───────────────────────────────────────────────
          const Text('Période',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          if (isConge) ...[
            Row(children: [
              Expanded(child: _datePick('Date de début *', _debut,
                  (d) => setState(() => _debut = d))),
              const SizedBox(width: 12),
              Expanded(child: _datePick('Date de fin *', _fin,
                  (d) => setState(() => _fin = d))),
            ]),
          ] else ...[
            DropdownButtonFormField<String>(
              value: _periode,
              decoration: const InputDecoration(labelText: 'Période *'),
              items: const [
                DropdownMenuItem(value: 'journee',    child: Text('Journée entière')),
                DropdownMenuItem(value: 'matin',      child: Text('Matin')),
                DropdownMenuItem(value: 'apres_midi', child: Text('Après-midi')),
              ],
              onChanged: (v) => setState(() => _periode = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _dureeValeur % 1 == 0
                      ? _dureeValeur.toInt().toString()
                      : _dureeValeur.toString(),
                  decoration: const InputDecoration(labelText: "Durée d'absence *"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) setState(() => _dureeValeur = parsed);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _dureeUnite,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: const [
                    DropdownMenuItem(value: 'jour',  child: Text('Jour(s)')),
                    DropdownMenuItem(value: 'heure', child: Text('Heure(s)')),
                  ],
                  onChanged: (v) => setState(() => _dureeUnite = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _datePick('Date de départ *', _depart,
                  (d) => setState(() => _depart = d))),
              const SizedBox(width: 12),
              Expanded(child: _datePick('Date de reprise *', _reprise,
                  (d) => setState(() => _reprise = d))),
            ]),
          ],
          const SizedBox(height: 16),

          // ── Motif ─────────────────────────────────────────────────────────
          const Text('Motif ou Justificatif',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _motifCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
          ),
          const SizedBox(height: 12),

          // ── Justificatif (fichier) ────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(
                  _justificatifName ?? 'Joindre un justificatif (optionnel)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _justificatifName != null
                        ? AppTheme.primary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
            if (_justificatif != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                tooltip: 'Supprimer le fichier',
                onPressed: () => setState(() {
                  _justificatif     = null;
                  _justificatifName = null;
                }),
              ),
          ]),
          if (_justificatifName != null)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text('PDF ou image · max 5 Mo',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ),
          const SizedBox(height: 12),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Enregistrer' : isResubmit ? 'Re-soumettre' : 'Soumettre'),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _datePick(String label, DateTime? value, void Function(DateTime) onPicked) =>
    GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onPicked(d);
      },
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: value == null ? '' :
              '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year}',
          ),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
}

// ── Document WebView screen ───────────────────────────────────────────────────

class _DocumentScreen extends StatefulWidget {
  final String html;
  const _DocumentScreen({required this.html});

  @override
  State<_DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<_DocumentScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Autorisation de permission'),
      actions: [
        if (!_loading)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _controller.reload();
            },
          ),
      ],
    ),
    body: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_loading)
        const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    ]),
  );
}
