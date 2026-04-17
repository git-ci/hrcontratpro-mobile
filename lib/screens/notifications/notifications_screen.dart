import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
                          data['icon'] ?? '🔔',
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
                      trailing: Column(
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
                      onTap: () async {
                        if (!isRead) {
                          await ApiService.markRead(n['id']);
                          await _load();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '';
    try {
      final dt  = DateTime.parse(d).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24)   return '${diff.inHours}h';
      if (diff.inDays < 7)     return '${diff.inDays}j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}
