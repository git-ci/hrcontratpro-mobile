import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int _page = 1;
  bool _hasMore = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _users = [];
      _hasMore = true;
    }
    if (!_hasMore && !reset) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getUsers(
          query: _query.isEmpty ? null : _query, page: _page);
      final list = (data['data'] ?? []) as List;
      setState(() {
        _users.addAll(list);
        _page++;
        _hasMore = data['next_page_url'] != null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = AuthService.isDG || AuthService.isRH;
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Employés'),
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () =>
                  context.go('/${AuthService.role}/employees/create'),
            ),
        ],
      ),
      body: Column(children: [
        // Recherche
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Rechercher un employé…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                        _load(reset: true);
                      })
                  : null,
            ),
            onChanged: (v) {
              setState(() => _query = v);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (_query == v) _load(reset: true);
              });
            },
          ),
        ),
        Expanded(
          child: _loading && _users.isEmpty
              ? const LoadingWidget()
              : _error != null && _users.isEmpty
                  ? ErrorWidget2(
                      message: _error!, onRetry: () => _load(reset: true))
                  : _users.isEmpty
                      ? const EmptyWidget(
                          icon: '👥', title: 'Aucun employé trouvé')
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.builder(
                            itemCount: _users.length + (_hasMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i == _users.length) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) => _load());
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              return EmployeeCard(
                                user: _users[i] as Map<String, dynamic>,
                                onTap: () => context.push(
                                    '/${AuthService.role}/employees/${_users[i]['id']}'),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ── Détail employé ──────────────────────────────────────────────────────────────
class EmployeeDetailScreen extends StatefulWidget {
  final int userId;
  const EmployeeDetailScreen({super.key, required this.userId});
  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await ApiService.getUser(widget.userId);
      setState(() {
        _user = u;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleStatus() async {
    final u = _user!;
    final isActive = u['status'] == 'active';
    try {
      if (isActive)
        await ApiService.deactivateUser(u['id']);
      else
        await ApiService.activateUser(u['id']);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isActive ? 'Compte désactivé' : 'Compte activé'),
            backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?['name'] ?? 'Employé'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/${AuthService.role}/employees'),
        ),
        actions: [
          if (_user != null && (AuthService.isDG || AuthService.isRH))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context
                  .go('/${AuthService.role}/employees/${widget.userId}/edit'),
            ),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : _error != null
              ? ErrorWidget2(message: _error!, onRetry: _load)
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final u = _user!;
    final isActive = u['status'] == 'active';
    final contract = u['active_contract'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête profil ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                (u['name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(u['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  if (u['position'] != null)
                    Text(u['position'],
                        style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  if (u['department'] != null)
                    Text(u['department'],
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12)),
                  if (u['matricule'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('🪪 ${u['matricule']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ),
                ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Infos ────────────────────────────────────────────────────────────
        Card(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            InfoRow(
                icon: Icons.email, label: 'Email', value: u['email'] ?? '—'),
            const Divider(),
            InfoRow(
                icon: Icons.phone,
                label: 'Téléphone',
                value: u['phone'] ?? '—'),
            const Divider(),
            InfoRow(
                icon: Icons.cake,
                label: 'Naissance',
                value: _fmtDate(u['birth_date'])),
            const Divider(),
            InfoRow(
                icon: Icons.person,
                label: 'Genre',
                value: u['gender'] == 'M'
                    ? 'Homme'
                    : u['gender'] == 'F'
                        ? 'Femme'
                        : '—'),
            const Divider(),
            InfoRow(
                icon: Icons.badge,
                label: 'Rôle',
                value: u['role'] == 'dg'
                    ? 'Direction'
                    : u['role'] == 'rh'
                        ? 'RH'
                        : 'Employé'),
            const Divider(),
            InfoRow(
                icon: Icons.circle,
                label: 'Statut',
                value: isActive ? 'Actif' : 'Inactif'),
          ]),
        )),

        // ── Contrat actif ────────────────────────────────────────────────────
        if (contract != null) ...[
          const SectionTitle(title: 'CONTRAT ACTIF'),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InfoRow(
                  icon: Icons.description,
                  label: 'Type',
                  value: contract['type']?.toString().toUpperCase() ?? '—'),
              const Divider(),
              InfoRow(
                  icon: Icons.euro,
                  label: 'Salaire',
                  value:
                      '${contract['salary'] ?? '—'} ${contract['currency'] ?? ''}'),
              const Divider(),
              InfoRow(
                  icon: Icons.date_range,
                  label: 'Début',
                  value: _fmtDate(contract['start_date'])),
              const Divider(),
              InfoRow(
                  icon: Icons.event,
                  label: 'Fin',
                  value: contract['end_date'] != null
                      ? _fmtDate(contract['end_date'])
                      : 'CDI (indéterminé)'),
            ]),
          )),
        ],

        // ── Actions ──────────────────────────────────────────────────────────
        if (AuthService.isDG) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _toggleStatus,
              icon: Icon(isActive ? Icons.block : Icons.check_circle),
              label:
                  Text(isActive ? 'Désactiver le compte' : 'Activer le compte'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? AppTheme.danger : AppTheme.success,
                side: BorderSide(
                    color: isActive ? AppTheme.danger : AppTheme.success),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}
