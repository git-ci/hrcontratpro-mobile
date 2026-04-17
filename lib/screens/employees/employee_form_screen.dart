import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class EmployeeFormScreen extends StatefulWidget {
  final int? userId; // null = création, non-null = modification
  const EmployeeFormScreen({super.key, this.userId});
  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  bool get _isEdit => widget.userId != null;

  // Controllers
  final _name = TextEditingController();
  final _matricule = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _department = TextEditingController();
  final _position = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  String _gender = 'M';
  String _role = 'employee';
  DateTime? _birthDate;
  bool _obscurePw = true;
  bool _obscurePw2 = true;
  bool _loading = false;
  bool _loadingUser = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    try {
      final u = await ApiService.getUser(widget.userId!);
      _name.text = u['name'] ?? '';
      _matricule.text = u['matricule'] ?? '';
      _email.text = u['email'] ?? '';
      _phone.text = u['phone'] ?? '';
      _address.text = u['address'] ?? '';
      _department.text = u['department'] ?? '';
      _position.text = u['position'] ?? '';
      _gender = u['gender'] ?? 'M';
      _role = u['role'] ?? 'employee';
      if (u['birth_date'] != null) {
        try {
          _birthDate = DateTime.parse(u['birth_date']);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _submit() async {
    // Validations
    if (_name.text.isEmpty || _email.text.isEmpty) {
      setState(() => _error = 'Le nom et l\'email sont obligatoires.');
      return;
    }
    if (!_isEdit) {
      if (_password.text.isEmpty) {
        setState(() => _error = 'Le mot de passe est obligatoire.');
        return;
      }
      if (_password.text != _passwordConfirm.text) {
        setState(() => _error = 'Les mots de passe ne correspondent pas.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'matricule': _matricule.text.trim().toUpperCase().isEmpty
            ? null
            : _matricule.text.trim().toUpperCase(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'department': _department.text.trim(),
        'position': _position.text.trim(),
        'gender': _gender,
        'role': _role,
        if (_birthDate != null)
          'birth_date': '${_birthDate!.year}-'
              '${_birthDate!.month.toString().padLeft(2, '0')}-'
              '${_birthDate!.day.toString().padLeft(2, '0')}',
        if (!_isEdit) ...{
          'password': _password.text,
          'password_confirmation': _passwordConfirm.text,
        },
      };

      if (_isEdit) {
        await ApiService.updateUser(widget.userId!, data);
      } else {
        await ApiService.createUser(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Employé mis à jour ✅' : 'Employé créé ✅'),
          backgroundColor: AppTheme.success,
        ));
        if (context.canPop())
          context.pop();
        else
          context.go('/${AuthService.role}/employees');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _matricule.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _department.dispose();
    _position.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier l\'employé' : 'Nouvel employé'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop())
              context.pop();
            else
              context.go('/${AuthService.role}/employees');
          },
        ),
      ),
      body: _loadingUser
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Identité ────────────────────────────────────────────────────
                    _sectionTitle('👤 Identité'),
                    _row([
                      _field(_name, 'Nom complet *', icon: Icons.person),
                      _field(_matricule, '🪪 Matricule', hint: 'EMP-001'),
                    ]),
                    _row([
                      _datePicker(),
                      _dropdown(
                          'Genre *',
                          _gender,
                          {'M': 'Homme', 'F': 'Femme'},
                          (v) => setState(() => _gender = v!)),
                    ]),
                    _row([
                      _field(_phone, 'Téléphone',
                          icon: Icons.phone, type: TextInputType.phone),
                      _field(_address, 'Adresse', icon: Icons.home),
                    ]),

                    const SizedBox(height: 8),

                    // ── Poste ────────────────────────────────────────────────────────
                    _sectionTitle('🏢 Poste & Rôle'),
                    _row([
                      _field(_department, 'Département', icon: Icons.business),
                      _field(_position, 'Poste', icon: Icons.work),
                    ]),
                    if (AuthService.isDG) ...[
                      const SizedBox(height: 12),
                      _dropdown(
                          'Rôle *',
                          _role,
                          {
                            'employee': '👤 Employé',
                            'rh': '👥 RH',
                            'dg': '🏛️ Direction',
                          },
                          (v) => setState(() => _role = v!)),
                    ],

                    const SizedBox(height: 8),

                    // ── Accès ────────────────────────────────────────────────────────
                    _sectionTitle('🔐 Accès au compte'),
                    _field(_email, 'Adresse e-mail *',
                        icon: Icons.email, type: TextInputType.emailAddress),
                    if (!_isEdit) ...[
                      const SizedBox(height: 12),
                      _row([
                        _passwordField(_password, 'Mot de passe *', _obscurePw,
                            () => setState(() => _obscurePw = !_obscurePw)),
                        _passwordField(
                            _passwordConfirm,
                            'Confirmer *',
                            _obscurePw2,
                            () => setState(() => _obscurePw2 = !_obscurePw2)),
                      ]),
                    ],

                    // ── Erreur ────────────────────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.danger.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppTheme.danger, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Bouton ────────────────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(_isEdit ? Icons.save : Icons.person_add),
                        label: Text(_isEdit
                            ? 'Enregistrer les modifications'
                            : 'Créer l\'employé'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
            ),
    );
  }

  // ── Helpers UI ──────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: .5)),
          const Divider(height: 8),
        ]),
      );

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
            children: children
                .map((w) => Expanded(
                        child: Padding(
                      padding: EdgeInsets.only(
                        left: children.indexOf(w) > 0 ? 6 : 0,
                        right:
                            children.indexOf(w) < children.length - 1 ? 6 : 0,
                      ),
                      child: w,
                    )))
                .toList()),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    String? hint,
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 18) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _passwordField(TextEditingController ctrl, String label, bool obscure,
          VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                size: 18),
            onPressed: toggle,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _dropdown(String label, String value, Map<String, String> options,
          ValueChanged<String?> onChange) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChange,
      );

  Widget _datePicker() => GestureDetector(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _birthDate ?? DateTime(1990),
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
          );
          if (d != null) setState(() => _birthDate = d);
        },
        child: AbsorbPointer(
          child: TextField(
            controller: TextEditingController(
              text: _birthDate == null
                  ? ''
                  : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                      '${_birthDate!.month.toString().padLeft(2, '0')}/'
                      '${_birthDate!.year}',
            ),
            decoration: const InputDecoration(
              labelText: 'Date de naissance',
              prefixIcon: Icon(Icons.cake, size: 18),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      );
}
