import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

String get _rolePrefix {
  final role = AuthService.role ?? 'employee';
  return role == 'employee' ? '/emp' : '/$role';
}

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});
  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  List<dynamic> _conversations = [];
  List<dynamic> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getConversations(),
        ApiService.getAnnouncements(),
      ]);
      setState(() {
        _conversations = results[0] as List<dynamic>;
        _announcements = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _canAnnounce =>
      AuthService.role == 'rh' || AuthService.role == 'dg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Messagerie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Nouvelle conversation',
            onPressed: _showNewConversation,
          ),
          if (_canAnnounce)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Nouvelle annonce',
              onPressed: _showAnnounceForm,
            ),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : _error != null
              ? ErrorWidget2(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      // ── Annonces ──────────────────────────────────
                      if (_announcements.isNotEmpty) ...[
                        const _SectionHeader(label: 'ANNONCES'),
                        ..._announcements.map((a) => _AnnouncementTile(
                              ann: a as Map<String, dynamic>,
                              canEdit: _canAnnounce &&
                                  a['sender']?['id'] == AuthService.user?['id'],
                              onDelete: () async {
                                await ApiService.deleteAnnouncement(a['id'] as int);
                                _load();
                              },
                              onEdit: (updated) {
                                setState(() {
                                  final idx = _announcements.indexWhere(
                                      (x) => x['id'] == updated['id']);
                                  if (idx != -1) _announcements[idx] = updated;
                                });
                              },
                            )),
                        const Divider(height: 1),
                      ],

                      // ── Conversations privées ──────────────────────
                      const _SectionHeader(label: 'MESSAGES PRIVÉS'),
                      if (_conversations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('Aucune conversation',
                                style: TextStyle(color: AppTheme.textMuted)),
                          ),
                        )
                      else
                        ..._conversations.map((c) => _ConversationTile(
                              conv: c,
                              onTap: () => context.push('$_rolePrefix/messaging/chat/${c['partner_id']}',
                                  extra: c['partner_name']),
                            )),
                    ],
                  ),
                ),
    );
  }

  void _showNewConversation() async {
    final users = await ApiService.getChatUsers();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nouvelle conversation',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i] as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accent.withOpacity(0.15),
                    child: Text((u['name'] as String? ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.accent, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(u['name'] ?? ''),
                  subtitle: Text(_roleLabel(u['role']),
                      style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('$_rolePrefix/messaging/chat/${u['id']}', extra: u['name']);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showAnnounceForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AnnounceFormSheet(onSent: _load),
    );
  }

  String _roleLabel(String? r) => switch (r) {
    'dg'       => 'Directeur Général',
    'rh'       => 'Ressources Humaines',
    'employee' => 'Employé',
    _          => r ?? '',
  };
}

// ── Tuile annonce ─────────────────────────────────────────────────────────────

class _AnnouncementTile extends StatelessWidget {
  final Map<String, dynamic> ann;
  final bool canEdit;
  final VoidCallback onDelete;
  final void Function(Map<String, dynamic> updated) onEdit;
  const _AnnouncementTile({
    required this.ann,
    required this.canEdit,
    required this.onDelete,
    required this.onEdit,
  });

  static const _colors = {
    'info'    : (Color(0xFF1565C0), Color(0xFFE3F2FD), Icons.info_outline),
    'warning' : (Color(0xFFE65100), Color(0xFFFFF3E0), Icons.warning_amber_outlined),
    'sanction': (Color(0xFFC62828), Color(0xFFFFEBEE), Icons.gavel_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final type = ann['type'] as String? ?? 'info';
    final cfg  = _colors[type] ?? _colors['info']!;
    final fg   = cfg.$1;
    final bg   = cfg.$2;
    final icon = cfg.$3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: fg),
        title: Text(ann['title'] ?? '',
            style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ann['body'] ?? '',
              style: TextStyle(fontSize: 12, color: fg.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(
            '${ann['sender']?['name'] ?? ''} · ${_fmtDate(ann['created_at'])}',
            style: TextStyle(fontSize: 10, color: fg.withOpacity(0.6)),
          ),
        ]),
        trailing: canEdit
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: fg.withOpacity(0.6)),
                onSelected: (value) {
                  if (value == 'edit')   _showEditSheet(context, fg);
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit',   child: Text('Modifier')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer',
                      style: TextStyle(color: Colors.red))),
                ],
              )
            : null,
      ),
    );
  }

  void _showEditSheet(BuildContext context, Color fg) {
    final titleCtrl = TextEditingController(text: ann['title'] as String? ?? '');
    final bodyCtrl  = TextEditingController(text: ann['body']  as String? ?? '');
    String type     = ann['type'] as String? ?? 'info';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Modifier l\'annonce',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Type chips
            Row(children: [
              for (final t in ['info', 'warning', 'sanction'])
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _TypeChip(
                    label: t == 'info' ? 'Info' : t == 'warning' ? 'Alerte' : 'Sanction',
                    color: t == 'info' ? const Color(0xFF1565C0)
                        : t == 'warning' ? const Color(0xFFE65100)
                        : const Color(0xFFC62828),
                    selected: type == t,
                    onTap: () => setLocal(() => type = t),
                  ),
                )),
            ]),
            const SizedBox(height: 12),

            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Titre', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final body  = bodyCtrl.text.trim();
                  if (title.isEmpty || body.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    final updated = await ApiService.editAnnouncement(
                        ann['id'] as int,
                        {'type': type, 'title': title, 'body': body});
                    onEdit(updated);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e')));
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '';
    try {
      final dt   = DateTime.parse(d).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24)   return '${diff.inHours}h';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

// ── Tuile conversation ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final dynamic conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name    = conv['partner_name'] as String? ?? '?';
    final body    = conv['body'] as String? ?? '';
    final unread  = (conv['unread_count'] as num?)?.toInt() ?? 0;
    final isMe    = conv['sender_id'] == AuthService.user?['id'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withOpacity(0.12),
        child: Text(name[0].toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.w700)),
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal)),
      subtitle: Text(
        '${isMe ? 'Vous : ' : ''}$body',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12,
            color: unread > 0 ? AppTheme.primary : AppTheme.textMuted,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal),
      ),
      trailing: unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$unread',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          : null,
      onTap: onTap,
    );
  }
}

// ── Formulaire annonce ────────────────────────────────────────────────────────

class _AnnounceFormSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _AnnounceFormSheet({required this.onSent});
  @override
  State<_AnnounceFormSheet> createState() => _AnnounceFormSheetState();
}

class _AnnounceFormSheetState extends State<_AnnounceFormSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _type     = 'info';
  int? _targetId;
  List<dynamic> _users = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ApiService.getChatUsers().then((u) {
      if (mounted) setState(() => _users = u);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiService.createAnnouncement({
        'type'           : _type,
        'title'          : _titleCtrl.text.trim(),
        'body'           : _bodyCtrl.text.trim(),
        if (_targetId != null) 'target_user_id': _targetId,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSent();
      }
    } catch (e) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Nouvelle annonce',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // Type
        Row(children: [
          for (final t in ['info', 'warning', 'sanction'])
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _TypeChip(
                label: t == 'info' ? 'Info' : t == 'warning' ? 'Alerte' : 'Sanction',
                color: t == 'info' ? const Color(0xFF1565C0)
                    : t == 'warning' ? const Color(0xFFE65100)
                    : const Color(0xFFC62828),
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              ),
            )),
        ]),
        const SizedBox(height: 12),

        // Destinataire
        DropdownButtonFormField<int?>(
          value: _targetId,
          decoration: const InputDecoration(
              labelText: 'Destinataire', hintText: 'Tout le monde (broadcast)',
              border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tout le monde')),
            ..._users.map((u) => DropdownMenuItem(
                value: u['id'] as int,
                child: Text(u['name'] ?? ''))),
          ],
          onChanged: (v) => setState(() => _targetId = v),
        ),
        const SizedBox(height: 12),

        // Titre
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
              labelText: 'Titre', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 12),

        // Corps
        TextField(
          controller: _bodyCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Message', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Envoyer'),
          ),
        ),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.color,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Center(child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color))),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(label,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppTheme.textMuted, letterSpacing: 0.8)),
  );
}
