import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/employee_documents_section.dart';

class EmployeeDocumentsManagementScreen extends StatefulWidget {
  final int? userId;
  final String? employeeName;

  const EmployeeDocumentsManagementScreen({
    super.key,
    this.userId,
    this.employeeName,
  });

  @override
  State<EmployeeDocumentsManagementScreen> createState() =>
      _EmployeeDocumentsManagementScreenState();
}

class _EmployeeDocumentsManagementScreenState
    extends State<EmployeeDocumentsManagementScreen> {
  List<dynamic> _personnel = [];
  Map<int, int> _documentCounts = {};
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _employeeName;

  bool get _showEmployeeList => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _employeeName = widget.employeeName;
    if (_showEmployeeList) {
      _loadEmployees();
    } else if (_employeeName == null) {
      _loadEmployee();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countsFuture = ApiService.getEmployeeDocumentCounts();
      final personnel = <Map<String, dynamic>>[];
      var page = 1;
      while (true) {
        final response = await ApiService.getUsers(page: page, perPage: 100);
        personnel.addAll(
          (response['data'] as List? ?? []).whereType<Map<String, dynamic>>(),
        );
        if (response['next_page_url'] == null) break;
        page++;
      }
      final counts = await countsFuture;
      final documentCounts = <int, int>{
        for (final item in counts)
          (item['user_id'] as num).toInt():
              (item['document_count'] as num).toInt(),
      };
      if (mounted) {
        setState(() {
          _personnel = personnel;
          _documentCounts = documentCounts;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmployee() async {
    try {
      final user = await ApiService.getUser(widget.userId!);
      if (mounted) setState(() => _employeeName = user['name']?.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showEmployeeList) return _buildEmployeeDocuments();
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Documents du personnel'),
        actions: [
          IconButton(
            onPressed: _loadEmployees,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const AnnouncementBanner(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un employé…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: _buildEmployeeList()),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            TextButton(
                onPressed: _loadEmployees, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    final query = _query.trim().toLowerCase();
    final personnel = _personnel.where((item) {
      final user = item as Map<String, dynamic>;
      return query.isEmpty ||
          [
            user['name'],
            user['email'],
            user['matricule'],
            user['department'],
            user['position'],
          ].any((value) =>
              value?.toString().toLowerCase().contains(query) ?? false);
    }).toList();

    if (personnel.isEmpty) {
      return const Center(child: Text('Aucun membre du personnel trouvé.'));
    }
    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: ListView.builder(
        itemCount: personnel.length,
        itemBuilder: (context, index) {
          final user = personnel[index] as Map<String, dynamic>;
          final roleLabel = switch (user['role']) {
            'dg' => 'Direction générale',
            'rh' => 'Ressources humaines',
            'employee' => 'Employé',
            _ => user['role']?.toString() ?? '',
          };
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_documentCounts[(user['id'] as num).toInt()] ?? 0}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text([
                user['position'],
                user['department'],
                user['email'],
                roleLabel,
              ]
                  .where(
                      (value) => value != null && value.toString().isNotEmpty)
                  .join(' · ')),
              trailing: const Icon(Icons.folder_open_outlined),
              onTap: () => context.push(
                '/rh/documents/${user['id']}',
                extra: user['name']?.toString(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeeDocuments() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/rh/documents'),
        ),
        title: Text(_employeeName ?? 'Documents'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppTheme.danger)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    EmployeeDocumentsSection(
                      userId: widget.userId!,
                      canUpload: AuthService.isRH,
                    ),
                  ],
                ),
    );
  }
}
