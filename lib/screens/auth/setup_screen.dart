import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/checkin_reminder_service.dart';
import '../../services/fcm_service.dart';
import '../../theme/app_theme.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading  = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  String? _globalError;
  Map<String, String> _fieldErrors = {};

  void _clearErrors() {
    _globalError = null;
    _fieldErrors = {};
  }

  Future<void> _submit() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm  = _confirmCtrl.text;

    // Validation locale
    final local = <String, String>{};
    if (name.isEmpty)     local['name']     = 'Le nom est obligatoire.';
    if (email.isEmpty)    local['email']    = 'L\'adresse e-mail est obligatoire.';
    if (password.isEmpty) local['password'] = 'Le mot de passe est obligatoire.';
    if (confirm.isEmpty)  local['password_confirmation'] = 'La confirmation est obligatoire.';
    if (password.isNotEmpty && confirm.isNotEmpty && password != confirm) {
      local['password_confirmation'] = 'Les mots de passe ne correspondent pas.';
    }
    if (local.isNotEmpty) {
      setState(() { _clearErrors(); _fieldErrors = local; });
      return;
    }

    setState(() { _loading = true; _clearErrors(); });

    try {
      final data = await ApiService.setupDG(
        name:                 name,
        email:                email,
        password:             password,
        passwordConfirmation: confirm,
      );

      final token = data['token'] as String?;
      final user  = data['user']  as Map<String, dynamic>?;
      if (token != null && user != null) {
        await AuthService.saveSession(token, user);
        await CheckinReminderService.requestPermissions();
        CheckinReminderService.scheduleReminders();
        await FcmService.init();
      }

      if (mounted) context.go('/dg/dashboard');
    } on ApiException catch (e) {
      setState(() {
        if (e.errors.isNotEmpty) {
          _fieldErrors = e.errors.map((k, v) => MapEntry(k, v.first));
        } else {
          _globalError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Champ avec affichage d'erreur sous le TextField via errorText
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    TextCapitalization capitalization = TextCapitalization.none,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    VoidCallback? onSubmit,
    String? helperText,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      textInputAction: action,
      textCapitalization: capitalization,
      obscureText: isObscured,
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      onChanged: (_) {
        if (_fieldErrors.containsKey(fieldKey)) {
          setState(() => _fieldErrors.remove(fieldKey));
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        helperText: helperText,
        helperMaxLines: 2,
        errorText: _fieldErrors[fieldKey],
        errorMaxLines: 3,
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.primaryLight, Color(0xFF1a1040)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'HrContratPro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configuration initiale',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Créer le compte Directeur Général',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ce compte sera le seul avec accès complet à l\'application.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      _field(
                        ctrl: _nameCtrl,
                        label: 'Nom complet',
                        icon: Icons.person_outline,
                        fieldKey: 'name',
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      _field(
                        ctrl: _emailCtrl,
                        label: 'Adresse e-mail',
                        icon: Icons.email_outlined,
                        fieldKey: 'email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      _field(
                        ctrl: _passCtrl,
                        label: 'Mot de passe',
                        icon: Icons.lock_outline,
                        fieldKey: 'password',
                        isObscured: _obscure1,
                        onToggleObscure: () => setState(() => _obscure1 = !_obscure1),
                        helperText: 'Min. 8 caractères, majuscule et chiffre requis',
                      ),
                      const SizedBox(height: 16),

                      _field(
                        ctrl: _confirmCtrl,
                        label: 'Confirmer le mot de passe',
                        icon: Icons.lock_outline,
                        fieldKey: 'password_confirmation',
                        action: TextInputAction.done,
                        isObscured: _obscure2,
                        onToggleObscure: () => setState(() => _obscure2 = !_obscure2),
                        onSubmit: _submit,
                      ),

                      // Erreur globale (non liée à un champ spécifique)
                      if (_globalError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _globalError!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Créer le compte DG'),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
