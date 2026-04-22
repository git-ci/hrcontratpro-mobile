import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/checkin_reminder_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_drawer.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/employees/employees_screen.dart';
import 'screens/employees/employee_form_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/attendance/qr_scan_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/contracts/contracts_screen.dart';
import 'screens/requests/requests_screen.dart';
import 'screens/leaves/leaves_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadFromStorage();
  await CheckinReminderService.init();

  // Déconnexion automatique sur 401 (session expirée / token invalide)
  ApiService.onUnauthorized = () async {
    await AuthService.clearSession();
    await CheckinReminderService.cancelReminders();
    _router.go('/login');
  };

  if (AuthService.isLoggedIn) {
    await CheckinReminderService.requestPermissions();
    CheckinReminderService.scheduleReminders();
  }

  runApp(const HrContratProApp());
}

// ── Router ────────────────────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/',
  redirect: (ctx, state) async {
    final loggedIn = AuthService.isLoggedIn;
    final loc = state.matchedLocation;
    final isSplash  = loc == '/';
    final isAuthPage = loc == '/login';

    if (isSplash) return null; // Le splash gère lui-même la navigation
    if (!loggedIn && !isAuthPage) return '/login';
    if (loggedIn && isAuthPage) return AuthService.initialRoute;
    return null;
  },
  routes: [
    // ── Auth ────────────────────────────────────────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

    // ── DG Shell ────────────────────────────────────────────────────────────
    ShellRoute(
      builder: (ctx, state, child) => _RoleShell(role: 'dg', child: child),
      routes: [
        GoRoute(
            path: '/dg/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/dg/employees', builder: (_, __) => const EmployeesScreen()),
        GoRoute(
            path: '/dg/employees/create',
            builder: (_, __) => const EmployeeFormScreen()),
        GoRoute(
            path: '/dg/employees/:id',
            builder: (_, s) => EmployeeDetailScreen(
                userId: int.parse(s.pathParameters['id']!))),
        GoRoute(
            path: '/dg/employees/:id/edit',
            builder: (_, s) =>
                EmployeeFormScreen(userId: int.parse(s.pathParameters['id']!))),
        GoRoute(
            path: '/dg/notifications',
            builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/dg/scan', builder: (_, __) => const QrScanScreen()),
        // Autres routes DG → placeholder pour extension future
        GoRoute(
            path: '/dg/contracts', builder: (_, __) => const ContractsScreen()),
        GoRoute(
            path: '/dg/requests', builder: (_, __) => const RequestsScreen()),
        GoRoute(path: '/dg/leaves', builder: (_, __) => const LeavesScreen()),
        GoRoute(
            path: '/dg/attendance',
            builder: (_, __) => const AttendanceScreen()),
      ],
    ),

    // ── RH Shell ────────────────────────────────────────────────────────────
    ShellRoute(
      builder: (ctx, state, child) => _RoleShell(role: 'rh', child: child),
      routes: [
        GoRoute(
            path: '/rh/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/rh/employees', builder: (_, __) => const EmployeesScreen()),
        GoRoute(
            path: '/rh/employees/create',
            builder: (_, __) => const EmployeeFormScreen()),
        GoRoute(
            path: '/rh/employees/:id',
            builder: (_, s) => EmployeeDetailScreen(
                userId: int.parse(s.pathParameters['id']!))),
        GoRoute(
            path: '/rh/employees/:id/edit',
            builder: (_, s) =>
                EmployeeFormScreen(userId: int.parse(s.pathParameters['id']!))),
        GoRoute(
            path: '/rh/notifications',
            builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/rh/scan', builder: (_, __) => const QrScanScreen()),
        GoRoute(
            path: '/rh/contracts', builder: (_, __) => const ContractsScreen()),
        GoRoute(
            path: '/rh/requests', builder: (_, __) => const RequestsScreen()),
        GoRoute(path: '/rh/leaves', builder: (_, __) => const LeavesScreen()),
        GoRoute(
            path: '/rh/attendance',
            builder: (_, __) => const AttendanceScreen()),
      ],
    ),

    // ── Employé Shell ────────────────────────────────────────────────────────
    ShellRoute(
      builder: (ctx, state, child) => _RoleShell(role: 'emp', child: child),
      routes: [
        GoRoute(
            path: '/emp/dashboard',
            builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/emp/scan', builder: (_, __) => const QrScanScreen()),
        GoRoute(
            path: '/emp/notifications',
            builder: (_, __) => const NotificationsScreen()),
        GoRoute(
            path: '/emp/contracts',
            builder: (_, __) => const ContractsScreen()),
        GoRoute(path: '/emp/leaves', builder: (_, __) => const LeavesScreen()),
        GoRoute(
            path: '/emp/attendance',
            builder: (_, __) => const AttendanceScreen()),
      ],
    ),
  ],
);

// ── App ───────────────────────────────────────────────────────────────────────
class HrContratProApp extends StatelessWidget {
  const HrContratProApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'HrContratPro',
        theme: AppTheme.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}

// ── Shell avec BottomNav selon le rôle ────────────────────────────────────────
class _RoleShell extends StatelessWidget {
  final String role;
  final Widget child;

  const _RoleShell({required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final items = _navItems(role);
    final idx = items.indexWhere((i) => location.startsWith(i.route));

    return Scaffold(
      drawer: AppDrawer(role: role),
      body: Builder(
        builder: (ctx) => ShellScope(
          openDrawer: () => Scaffold.of(ctx).openDrawer(),
          child: child,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx < 0 ? 0 : idx,
        onTap: (i) => context.go(items[i].route),
        items: items
            .map((i) =>
                BottomNavigationBarItem(icon: Icon(i.icon), label: i.label))
            .toList(),
      ),
    );
  }

  List<_NavItem> _navItems(String role) {
    switch (role) {
      case 'dg':
        return [
          _NavItem('/$role/dashboard', Icons.dashboard_outlined, 'Tableau'),
          _NavItem('/$role/employees', Icons.people_outline, 'Employés'),
          _NavItem('/$role/attendance', Icons.schedule, 'Pointage'),
          _NavItem('/$role/requests', Icons.assignment_outlined, 'Demandes'),
          _NavItem(
              '/$role/notifications', Icons.notifications_outlined, 'Notifs'),
        ];
      case 'rh':
        return [
          _NavItem('/$role/dashboard', Icons.dashboard_outlined, 'Tableau'),
          _NavItem('/$role/employees', Icons.people_outline, 'Employés'),
          _NavItem('/$role/attendance', Icons.schedule, 'Pointage'),
          _NavItem('/$role/contracts', Icons.description_outlined, 'Contrats'),
          _NavItem(
              '/$role/notifications', Icons.notifications_outlined, 'Notifs'),
        ];
      default:
        return [
          _NavItem('/emp/dashboard', Icons.home_outlined, 'Accueil'),
          _NavItem('/emp/scan', Icons.qr_code_scanner, 'Scanner'),
          _NavItem('/emp/attendance', Icons.schedule, 'Pointage'),
          _NavItem('/emp/contracts', Icons.description_outlined, 'Contrats'),
          _NavItem(
              '/emp/notifications', Icons.notifications_outlined, 'Notifs'),
        ];
    }
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}

// ── Placeholder ───────────────────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Module en cours de développement',
                style: TextStyle(color: AppTheme.textMuted)),
          ]),
        ),
      );
}
