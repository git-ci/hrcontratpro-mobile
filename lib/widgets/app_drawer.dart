import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// ── ShellScope ────────────────────────────────────────────────────────────────
class ShellScope extends InheritedWidget {
  final VoidCallback openDrawer;
  const ShellScope({super.key, required this.openDrawer, required super.child});

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

// ── DrawerMenuButton ──────────────────────────────────────────────────────────
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: scope.openDrawer,
      tooltip: 'Menu',
    );
  }
}

// ── AppDrawer ─────────────────────────────────────────────────────────────────
class AppDrawer extends StatefulWidget {
  final String role;
  const AppDrawer({super.key, required this.role});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Uint8List? _photoBytes;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final bytes = await ApiService.getProfilePhotoBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user      = AuthService.user;
    final name      = user?['name'] ?? '';
    final email     = user?['email'] ?? '';
    final prefix    = widget.role == 'employee' ? 'emp' : widget.role;
    final location  = GoRouterState.of(context).matchedLocation;

    final roleLabel = widget.role == 'dg'
        ? 'Direction Générale'
        : widget.role == 'rh'
            ? 'Ressources Humaines'
            : 'Employé';
    final roleColor = widget.role == 'dg'
        ? AppTheme.dgColor
        : widget.role == 'rh'
            ? AppTheme.rhColor
            : AppTheme.empColor;

    final items = _navItems(prefix);

    return Drawer(
      child: Column(children: [
        // ── En-tête ───────────────────────────────────────────────────────────
        DrawerHeader(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [roleColor, roleColor.withOpacity(0.75)]),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Avatar avec photo ou initiale
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage:
                  _photoBytes != null ? MemoryImage(_photoBytes!) : null,
              child: _photoBytes == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8)),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(roleLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // ── Navigation ────────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: items.map((item) {
              final isActive = location.startsWith(item.route);
              return ListTile(
                dense: true,
                leading: Icon(item.icon,
                    color: isActive ? roleColor : AppTheme.textMuted,
                    size: 22),
                title: Text(item.label,
                    style: TextStyle(
                      color: isActive ? roleColor : null,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    )),
                selected: isActive,
                selectedTileColor: roleColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.route);
                },
              );
            }).toList(),
          ),
        ),

        // ── Bas du drawer ─────────────────────────────────────────────────────
        const Divider(height: 1),
        ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline, color: AppTheme.textMuted),
          title: const Text('Mon profil', style: TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            context.go('/profile');
          },
        ),
        ListTile(
          dense: true,
          leading: _loggingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.danger),
                )
              : const Icon(Icons.logout, color: AppTheme.danger),
          title: Text(
            _loggingOut ? 'Déconnexion…' : 'Se déconnecter',
            style: const TextStyle(color: AppTheme.danger, fontSize: 14),
          ),
          enabled: !_loggingOut,
          onTap: _loggingOut ? null : _logout,
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  List<_DrawerItem> _navItems(String prefix) {
    switch (prefix) {
      case 'dg':
        return const [
          _DrawerItem('/dg/dashboard',      Icons.dashboard_outlined,    'Tableau de bord'),
          _DrawerItem('/dg/employees',       Icons.people_outline,        'Employés'),
          _DrawerItem('/dg/attendance',      Icons.schedule_outlined,     'Pointage'),
          _DrawerItem('/dg/contracts',       Icons.description_outlined,  'Contrats'),
          _DrawerItem('/dg/requests',        Icons.assignment_outlined,   'Demandes'),
          _DrawerItem('/dg/leaves',          Icons.beach_access_outlined, 'Congés'),
          _DrawerItem('/dg/notifications',   Icons.notifications_outlined,'Notifications'),
        ];
      case 'rh':
        return const [
          _DrawerItem('/rh/dashboard',      Icons.dashboard_outlined,    'Tableau de bord'),
          _DrawerItem('/rh/employees',       Icons.people_outline,        'Employés'),
          _DrawerItem('/rh/attendance',      Icons.schedule_outlined,     'Pointage'),
          _DrawerItem('/rh/contracts',       Icons.description_outlined,  'Contrats'),
          _DrawerItem('/rh/requests',        Icons.assignment_outlined,   'Demandes'),
          _DrawerItem('/rh/leaves',          Icons.beach_access_outlined, 'Congés'),
          _DrawerItem('/rh/notifications',   Icons.notifications_outlined,'Notifications'),
        ];
      default: // emp
        return const [
          _DrawerItem('/emp/dashboard',     Icons.home_outlined,         'Accueil'),
          _DrawerItem('/emp/scan',           Icons.qr_code_scanner,      'Scanner QR'),
          _DrawerItem('/emp/attendance',     Icons.schedule_outlined,     'Pointage'),
          _DrawerItem('/emp/contracts',      Icons.description_outlined,  'Mes contrats'),
          _DrawerItem('/emp/leaves',         Icons.beach_access_outlined, 'Mes congés'),
          _DrawerItem('/emp/notifications',  Icons.notifications_outlined,'Notifications'),
        ];
    }
  }
}

class _DrawerItem {
  final String route;
  final IconData icon;
  final String label;
  const _DrawerItem(this.route, this.icon, this.label);
}
