import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/employee_documents_section.dart';

class EmployeeDocumentsScreen extends StatelessWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.user?['id'] as int?;
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Mes documents'),
      ),
      body: Column(
        children: [
          const AnnouncementBanner(),
          Expanded(
            child: userId == null
                ? const Center(child: Text('Compte utilisateur introuvable.'))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      EmployeeDocumentsSection(
                        userId: userId,
                        title: 'Mes documents administratifs',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
