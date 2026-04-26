import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifs = [];
  bool  _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getNotifications();
      setState(() { _notifs = (data['data'] ?? []) as List; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllRead();
    await _load();
  }

  String get _prefix => switch (AuthService.role) {
    'dg' => '/dg',
    'rh' => '/rh',
    _    => '/emp',
  };

  String? _destFor(Map<String, dynamic> data) {
    final type   = data['type'] as String? ?? '';
    final prefix = _prefix;
    if (type == 'payslip_uploaded')                       return '$prefix/payslips';
    if (type == 'contract_expiry' || type == 'contract_created') return '$prefix/contracts';
    if (type == 'contract_request')                       return '$prefix/requests';
    if (type == 'contract_decision')                      return AuthService.isEmp ? '/emp/contracts' : '$prefix/requests';
    if (type == 'absence_detected')                       return '$prefix/attendance';
    if (type.startsWith('leave_plan_'))                   return '$prefix/leaves';
    return null;
  }

  Future<void> _showDetail(Map<String, dynamic> n) async {
    final data   = n['data'] as Map<String, dynamic>? ?? {};
    final isRead = n['read_at'] != null;
    final dest   = _destFor(data);

    if (!isRead) {
      try { await ApiService.markRead(n['id'] as String); } catch (_) {}
      if (mounted) setState(() { n['read_at'] = DateTime.now().toIso8601String(); });
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(
                  _resolveIcon(data['icon'] as String?),
                  style: const TextStyle(fontSize: 20),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['title'] ?? data['message'] ?? 'Notification',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            if (data['body'] != null) ...[
              const SizedBox(height: 12),
              Text(
                data['body'] as String,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _fmtDateFull(n['created_at']),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (dest != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(dest);
                  },
                  child: const Text('Voir le détail'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Notifications'),
        actions: [
          if (_notifs.any((n) => n['read_at'] == null))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lire', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorWidget2(message: _error!, onRetry: _load)
        : _notifs.isEmpty
          ? const EmptyWidget(icon: '🔔', title: 'Aucune notification')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _notifs.length,
                itemBuilder: (ctx, i) {
                  final n      = _notifs[i] as Map<String, dynamic>;
                  final isRead = n['read_at'] != null;
                  final data   = n['data'] as Map<String, dynamic>? ?? {};
                  final hasNav = _hasNavigation(data['type'] as String?);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: isRead ? null : AppTheme.accent.withOpacity(0.05),
                    child: ListTile(
                      leading: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: isRead
                            ? AppTheme.border
                            : AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(
                          _resolveIcon(data['icon'] as String?),
                          style: const TextStyle(fontSize: 18),
                        )),
                      ),
                      title: Text(
                        data['title'] ?? data['message'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: data['body'] != null
                        ? Text(data['body'], style: const TextStyle(fontSize: 12),
                            maxLines: 2, overflow: TextOverflow.ellipsis)
                        : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isRead)
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accent, shape: BoxShape.circle),
                                ),
                              const SizedBox(height: 4),
                              Text(_fmtDate(n['created_at']),
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                          if (hasNav) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                          ],
                        ],
                      ),
                      onTap: () => _showDetail(n),
                    ),
                  );
                },
              ),
            ),
    );
  }

  bool _hasNavigation(String? type) {
    if (type == null) return false;
    return type == 'payslip_uploaded'  ||
           type == 'contract_expiry'   ||
           type == 'contract_created'  ||
           type == 'contract_request'  ||
           type == 'contract_decision' ||
           type == 'absence_detected'  ||
           type.startsWith('leave_plan_');
  }

  static const _iconMap = {
    'file-text'      : '📄',
    'check-circle'   : '✅',
    'x-circle'       : '❌',
    'bell'           : '🔔',
    'alert-triangle' : '⚠️',
    'calendar'       : '📅',
    'user'           : '👤',
    'clock'          : '🕐',
    'info'           : 'ℹ️',
    'receipt'        : '🧾',
  };

  String _resolveIcon(String? raw) {
    if (raw == null || raw.isEmpty) return '🔔';
    return _iconMap[raw] ?? raw;
  }

  String _fmtDate(String? d) {
    if (d == null) return '';
    try {
      final dt   = DateTime.parse(d).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24)   return '${diff.inHours}h';
      if (diff.inDays < 7)     return '${diff.inDays}j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  String _fmtDateFull(String? d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} à $h:$m';
    } catch (_) { return ''; }
  }
}
