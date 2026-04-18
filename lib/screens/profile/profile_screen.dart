import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _changingPw = false;
  final _oldPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confPw = TextEditingController();
  String? _pwError;
  bool _loading = false;
  bool _photoLoading = false;
  bool _hasPhoto = false;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final bytes = await ApiService.getProfilePhotoBytes();
    if (mounted) {
      setState(() {
        _photoBytes = bytes;
        _hasPhoto = bytes != null;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  Future<void> _changePassword() async {
    if (_newPw.text != _confPw.text) {
      setState(() => _pwError = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _loading = true;
      _pwError = null;
    });
    try {
      await ApiService.changePassword({
        'current_password': _oldPw.text,
        'password': _newPw.text,
        'password_confirmation': _confPw.text,
      });
      setState(() {
        _changingPw = false;
        _loading = false;
      });
      _oldPw.clear();
      _newPw.clear();
      _confPw.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mot de passe modifié !'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      setState(() {
        _pwError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'camera_access_denied' => 'Accès à la caméra refusé. Activez-le dans Réglages.',
        'photo_access_denied'  => 'Accès à la galerie refusé. Activez-le dans Réglages.',
        'no_camera'            => 'Aucune caméra disponible sur cet appareil.',
        _                      => 'Impossible d\'accéder à la caméra : ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
      return;
    }
    if (picked == null) return;
    setState(() => _photoLoading = true);
    try {
      await ApiService.uploadProfilePhoto(File(picked.path));
      await _loadPhoto();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _photoLoading = true);
    try {
      await ApiService.deleteProfilePhoto();
      if (mounted) setState(() { _photoBytes = null; _hasPhoto = false; });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Prendre une photo'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadPhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir depuis la galerie'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadPhoto(ImageSource.gallery);
            },
          ),
          if (_hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: const Text('Supprimer la photo',
                  style: TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(context);
                _deletePhoto();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallback = Text(
      initials,
      style: const TextStyle(
          fontSize: 32, color: Colors.white, fontWeight: FontWeight.w700),
    );

    Widget avatar;
    if (_photoLoading) {
      avatar = CircleAvatar(
        radius: 40,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    } else if (_photoBytes != null) {
      avatar = CircleAvatar(
        radius: 40,
        backgroundImage: MemoryImage(_photoBytes!),
        onBackgroundImageError: (_, __) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() { _photoBytes = null; _hasPhoto = false; });
          });
        },
      );
    } else {
      avatar = CircleAvatar(
        radius: 40,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: fallback,
      );
    }

    return Stack(
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: const Icon(Icons.camera_alt, size: 14, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.user;
    if (user == null) return const LoadingWidget();

    final name = user['name'] ?? '';
    final email = user['email'] ?? '';
    final role = user['role'] ?? '';
    final roleLabel = role == 'dg'
        ? 'Direction Générale'
        : role == 'rh'
            ? 'Ressources Humaines'
            : 'Employé';
    final roleColor = role == 'dg'
        ? AppTheme.dgColor
        : role == 'rh'
            ? AppTheme.rhColor
            : AppTheme.empColor;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
          const SizedBox(width: 8),
          const Text('Mon profil'),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final role = AuthService.role ?? 'employee';
            final prefix = role == 'employee' ? 'emp' : role;
            context.go('/$prefix/dashboard');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [roleColor, roleColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Stack(
                  children: [
                    _buildAvatar(name),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: roleColor, width: 2),
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 14, color: roleColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(email,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(roleLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Infos ─────────────────────────────────────────────────────────
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (user['matricule'] != null)
                InfoRow(
                    icon: Icons.badge,
                    label: 'Matricule',
                    value: user['matricule']),
              if (user['department'] != null)
                InfoRow(
                    icon: Icons.business,
                    label: 'Département',
                    value: user['department']),
              if (user['position'] != null)
                InfoRow(
                    icon: Icons.work, label: 'Poste', value: user['position']),
              if (user['phone'] != null)
                InfoRow(
                    icon: Icons.phone,
                    label: 'Téléphone',
                    value: user['phone']),
            ]),
          )),
          const SizedBox(height: 8),

          // ── Changer mot de passe ──────────────────────────────────────────
          Card(
              child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Changer le mot de passe'),
              trailing:
                  Icon(_changingPw ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _changingPw = !_changingPw),
            ),
            if (_changingPw)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(children: [
                  TextField(
                      controller: _oldPw,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Mot de passe actuel')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _newPw,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _confPw,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Confirmer')),
                  if (_pwError != null) ...[
                    const SizedBox(height: 8),
                    Text(_pwError!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _changePassword,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Mettre à jour'),
                    ),
                  ),
                ]),
              ),
          ])),
          const SizedBox(height: 8),

          // ── Déconnexion ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
