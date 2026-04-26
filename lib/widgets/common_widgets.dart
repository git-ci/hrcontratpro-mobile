import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Carte stat ──────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color  color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: color,
            )),
            Text(label, style: const TextStyle(
              fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Badge statut ────────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, Map<String, dynamic>> config;

  const StatusBadge({super.key, required this.status, required this.config});

  @override
  Widget build(BuildContext context) {
    final s     = config[status] ?? {'label': status, 'color': AppTheme.textMuted, 'icon': '•'};
    final color = s['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '${s['icon']} ${s['label']}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Carte employé ───────────────────────────────────────────────────────────────
class EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onTap;

  const EmployeeCard({super.key, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name  = user['name'] ?? '?';
    final dept  = user['department'] ?? '';
    final pos   = user['position'] ?? '';
    final mat   = user['matricule'] ?? '';
    final active= user['status'] == 'active';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dept.isNotEmpty || pos.isNotEmpty)
              Text('$pos${dept.isNotEmpty ? ' · $dept' : ''}',
                  style: const TextStyle(fontSize: 12)),
            if (mat.isNotEmpty)
              Text('🪪 $mat', style: const TextStyle(fontSize: 11, color: AppTheme.info)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            active ? 'Actif' : 'Inactif',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppTheme.success : AppTheme.textMuted,
            ),
          ),
        ),
        isThreeLine: mat.isNotEmpty,
      ),
    );
  }
}

// ── Loading ──────────────────────────────────────────────────────────────────────
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppTheme.primary),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ],
    ),
  );
}

// ── Erreur ────────────────────────────────────────────────────────────────────────
class ErrorWidget2 extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorWidget2({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    ),
  );
}

// ── Vide ─────────────────────────────────────────────────────────────────────────
class EmptyWidget extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;

  const EmptyWidget({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ),
      ],
    ),
  );
}

// ── Section titre ─────────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppTheme.textMuted, letterSpacing: .5,
        )),
        if (action != null) action!,
      ],
    ),
  );
}

// ── Info row ─────────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}
