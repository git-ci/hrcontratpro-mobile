import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common_widgets.dart';

// ── Statuts ──────────────────────────────────────────────────────────────────
const _contractStatuses = {
  'active':     {'label': 'Actif',     'color': AppTheme.success},
  'expired':    {'label': 'Expiré',    'color': AppTheme.danger},
  'terminated': {'label': 'Résilié',   'color': AppTheme.textMuted},
  'pending':    {'label': 'En attente','color': AppTheme.warning},
};

const _contractTypes = ['CDI', 'CDD', 'Stage', 'Alternance', 'Freelance'];

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});
  @override State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _contracts = [];
  bool   _loading = true;
  String? _error;
  String? _filterStatus;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: AuthService.isEmp ? 1 : 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load({String? status}) async {
    setState(() { _loading = true; _error = null; _filterStatus = status; });
    try {
      if (AuthService.isEmp) {
        final data = await ApiService.getMyContracts();
        setState(() { _contracts = data; _loading = false; });
      } else {
        final data = await ApiService.getContracts(page: 1, status: status);
        setState(() {
          _contracts = (data['data'] ?? []) as List;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Contrats'),
        actions: [
          if (AuthService.isDG || AuthService.isRH)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateDialog(),
            ),
        ],
        bottom: AuthService.isEmp ? null : TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (i) {
            final filters = [null, 'active', 'expired', 'terminated'];
            _load(status: filters[i]);
          },
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Actifs'),
            Tab(text: 'Expirés'),
            Tab(text: 'Résiliés'),
          ],
        ),
      ),
      body: _loading ? const LoadingWidget()
        : _error != null ? ErrorWidget2(message: _error!, onRetry: _load)
        : _contracts.isEmpty
          ? const EmptyWidget(icon: '📄', title: 'Aucun contrat trouvé')
          : RefreshIndicator(
              onRefresh: () => _load(status: _filterStatus),
              child: ListView.builder(
                itemCount: _contracts.length,
                itemBuilder: (_, i) => _ContractCard(
                  contract: _contracts[i] as Map<String, dynamic>,
                  onTap: () => _showDetail(_contracts[i] as Map<String, dynamic>),
                ),
              ),
            ),
    );
  }

  void _showDetail(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ContractDetail(contract: c, onRefresh: _load),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateContractForm(onCreated: _load),
    );
  }
}

// ── Carte contrat ──────────────────────────────────────────────────────────────
class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final VoidCallback onTap;
  const _ContractCard({required this.contract, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c      = contract;
    final status = c['status'] ?? 'active';
    final cfg    = _contractStatuses[status] ?? {'label': status, 'color': AppTheme.textMuted};
    final color  = cfg['color'] as Color;
    final type   = c['type']?.toString().toUpperCase() ?? '—';
    final name   = c['user']?['name'] ?? AuthService.user?['name'] ?? '—';
    final salary = c['salary'] != null ? '${c['salary']} ${c['currency'] ?? ''}' : '—';
    final start  = _fmtDate(c['start_date']);
    final end    = c['end_date'] != null ? _fmtDate(c['end_date']) : 'CDI';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(type.substring(0, type.length.clamp(0, 3)),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$start → $end', style: const TextStyle(fontSize: 12)),
          Text(salary, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(cfg['label'] as String,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ── Détail contrat ─────────────────────────────────────────────────────────────
class _ContractDetail extends StatefulWidget {
  final Map<String, dynamic> contract;
  final Function() onRefresh;
  const _ContractDetail({required this.contract, required this.onRefresh});
  @override State<_ContractDetail> createState() => _ContractDetailState();
}

class _ContractDetailState extends State<_ContractDetail> {
  bool _uploading  = false;
  bool _pdfLoading = false;

  Future<void> _openPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final bytes = await ApiService.downloadContractPdf(widget.contract['id']);
      final tmpDir = await getTemporaryDirectory();
      final file   = File('${tmpDir.path}/contrat_${widget.contract['id']}.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'ouvrir le PDF : ${result.message}'),
          backgroundColor: AppTheme.danger));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom,
        allowedExtensions: ['pdf']);
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.first.path!);
    setState(() => _uploading = true);
    try {
      await ApiService.uploadContractPdf(widget.contract['id'], file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF joint avec succès'),
            backgroundColor: AppTheme.success));
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showEditForm() async {
    Navigator.pop(context); // fermer le détail
    await showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditContractForm(
        contract: widget.contract,
        onSaved: widget.onRefresh,
      ),
    );
  }

  Future<void> _showRequestForm() async {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RequestForm(contractId: widget.contract['id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c      = widget.contract;
    final status = c['status'] ?? 'active';
    final cfg    = _contractStatuses[status] ?? {'label': status, 'color': AppTheme.textMuted};
    final color  = cfg['color'] as Color;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Expanded(child: Text(
            '${c['type']?.toString().toUpperCase()} — ${c['user']?['name'] ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(cfg['label'] as String,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if ((AuthService.isDG || AuthService.isRH) && status == 'active') ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              tooltip: 'Modifier',
              onPressed: _showEditForm,
            ),
          ],
        ]),
        const SizedBox(height: 16),
        const Divider(),

        Expanded(child: SingleChildScrollView(child: Column(children: [
          InfoRow(icon: Icons.person, label: 'Employé',
            value: c['user']?['name'] ?? '—'),
          InfoRow(icon: Icons.description, label: 'Type',
            value: c['type']?.toString().toUpperCase() ?? '—'),
          InfoRow(icon: Icons.euro, label: 'Salaire',
            value: '${c['salary'] ?? '—'} ${c['currency'] ?? ''}'),
          InfoRow(icon: Icons.date_range, label: 'Début',
            value: _fmtDate(c['start_date'])),
          InfoRow(icon: Icons.event, label: 'Fin',
            value: c['end_date'] != null ? _fmtDate(c['end_date']) : 'CDI'),
          if (c['notes'] != null)
            InfoRow(icon: Icons.notes, label: 'Notes', value: c['notes']),

          const SizedBox(height: 16),

          // Actions
          if (c['has_pdf'] == true)
            InkWell(
              onTap: _pdfLoading ? null : _openPdf,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3))),
                child: Row(children: [
                  _pdfLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppTheme.success))
                    : const Icon(Icons.picture_as_pdf, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _pdfLoading ? 'Ouverture en cours…' : 'Contrat PDF joint — Appuyer pour ouvrir',
                    style: const TextStyle(color: AppTheme.success,
                        fontWeight: FontWeight.w600))),
                  if (!_pdfLoading)
                    const Icon(Icons.open_in_new, size: 16, color: AppTheme.success),
                ]),
              ),
            )
          else if (AuthService.isDG || AuthService.isRH)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadPdf,
                icon: _uploading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
                label: const Text('Joindre le PDF'),
              ),
            ),

          const SizedBox(height: 10),
          if (status == 'active' && (AuthService.isDG || AuthService.isRH))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showRequestForm,
                icon: const Icon(Icons.send),
                label: const Text('Soumettre une demande'),
              ),
            ),
        ]))),
      ]),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ── Formulaire création contrat ───────────────────────────────────────────────
class _CreateContractForm extends StatefulWidget {
  final Function() onCreated;
  const _CreateContractForm({required this.onCreated});
  @override State<_CreateContractForm> createState() => _CreateContractFormState();
}

class _CreateContractFormState extends State<_CreateContractForm> {
  List<dynamic> _employees = [];
  int?   _selectedEmp;
  String _type     = 'CDI';
  final _salary    = TextEditingController();
  final _currency  = TextEditingController(text: 'XOF');
  DateTime? _start;
  DateTime? _end;
  final _notes     = TextEditingController();
  bool  _loading   = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadEmployees(); }

  Future<void> _loadEmployees() async {
    try {
      final data = await ApiService.getUsers();
      setState(() => _employees = (data['data'] ?? []) as List);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedEmp == null || _salary.text.isEmpty || _start == null) {
      setState(() => _error = 'Veuillez remplir tous les champs obligatoires.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.createContract({
        'user_id':    _selectedEmp,
        'type':       _type.toLowerCase(),
        'salary':     double.tryParse(_salary.text) ?? 0,
        'currency':   _currency.text,
        'start_date': _start!.toIso8601String().substring(0, 10),
        if (_end != null) 'end_date': _end!.toIso8601String().substring(0, 10),
        'notes':      _notes.text,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Nouveau contrat',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Employé
        DropdownButtonFormField<int>(
          value: _selectedEmp,
          decoration: const InputDecoration(labelText: 'Employé *'),
          items: _employees.map((e) => DropdownMenuItem<int>(
            value: e['id'] as int,
            child: Text(e['name'] ?? ''),
          )).toList(),
          onChanged: (v) => setState(() => _selectedEmp = v),
        ),
        const SizedBox(height: 12),

        // Type
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type *'),
          items: _contractTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? 'CDI'),
        ),
        const SizedBox(height: 12),

        // Salaire + devise
        Row(children: [
          Expanded(child: TextField(controller: _salary,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Salaire *'))),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: TextField(controller: _currency,
            decoration: const InputDecoration(labelText: 'Devise'))),
        ]),
        const SizedBox(height: 12),

        // Dates
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(_start == null ? 'Début *' : _fmtDate(_start!)),
            onPressed: () async {
              final d = await showDatePicker(context: context,
                initialDate: DateTime.now(), firstDate: DateTime(2000),
                lastDate: DateTime(2100));
              if (d != null) setState(() => _start = d);
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.event, size: 16),
            label: Text(_end == null ? 'Fin (CDI)' : _fmtDate(_end!)),
            onPressed: () async {
              final d = await showDatePicker(context: context,
                initialDate: DateTime.now(), firstDate: DateTime(2000),
                lastDate: DateTime(2100));
              if (d != null) setState(() => _end = d);
            },
          )),
        ]),
        const SizedBox(height: 12),

        TextField(controller: _notes, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes')),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Créer le contrat'),
        )),
      ])),
    );
  }

  String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

// ── Formulaire demande ─────────────────────────────────────────────────────────
class _RequestForm extends StatefulWidget {
  final int contractId;
  const _RequestForm({required this.contractId});
  @override State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  String _type  = 'salary_change';
  final _salary = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _endDate;
  String _newType = 'cdi';
  bool  _loading  = false;
  String? _error;

  Future<void> _submit() async {
    if (_reason.text.isEmpty) {
      setState(() => _error = 'La raison est obligatoire.'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.createRequest({
        'contract_id':           widget.contractId,
        'type':                  _type,
        'reason':                _reason.text,
        if (_salary.text.isNotEmpty) 'proposed_salary': double.tryParse(_salary.text),
        if (_endDate != null) 'proposed_end_date': _endDate!.toIso8601String().substring(0, 10),
        if (_type == 'type_change') 'proposed_contract_type': _newType,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande soumise !'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Soumettre une demande',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type de demande'),
          items: const [
            DropdownMenuItem(value: 'salary_change',   child: Text('Révision salariale')),
            DropdownMenuItem(value: 'renewal',         child: Text('Renouvellement')),
            DropdownMenuItem(value: 'termination',     child: Text('Résiliation')),
            DropdownMenuItem(value: 'type_change',     child: Text('Changement de type')),
          ],
          onChanged: (v) => setState(() => _type = v ?? 'salary_change'),
        ),
        const SizedBox(height: 12),

        if (_type == 'salary_change')
          TextField(controller: _salary, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nouveau salaire proposé')),
        if (_type == 'renewal')
          OutlinedButton.icon(
            icon: const Icon(Icons.event, size: 16),
            label: Text(_endDate == null ? 'Nouvelle date de fin'
              : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
            onPressed: () async {
              final d = await showDatePicker(context: context,
                initialDate: DateTime.now(), firstDate: DateTime.now(),
                lastDate: DateTime(2100));
              if (d != null) setState(() => _endDate = d);
            },
          ),
        if (_type == 'type_change')
          DropdownButtonFormField<String>(
            value: _newType,
            decoration: const InputDecoration(labelText: 'Nouveau type'),
            items: _contractTypes.map((t) => DropdownMenuItem(
              value: t.toLowerCase(), child: Text(t))).toList(),
            onChanged: (v) => setState(() => _newType = v ?? 'cdi'),
          ),

        const SizedBox(height: 12),
        TextField(controller: _reason, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison / Justification *')),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Soumettre'),
        )),
      ])),
    );
  }
}


// ── Formulaire modification contrat ──────────────────────────────────────────
class _EditContractForm extends StatefulWidget {
  final Map<String, dynamic> contract;
  final Function() onSaved;
  const _EditContractForm({required this.contract, required this.onSaved});
  @override State<_EditContractForm> createState() => _EditContractFormState();
}

class _EditContractFormState extends State<_EditContractForm> {
  late final TextEditingController _salary;
  late final TextEditingController _currency;
  late final TextEditingController _notes;
  late String _type;
  DateTime? _end;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _salary   = TextEditingController(text: c['salary']?.toString() ?? '');
    _currency = TextEditingController(text: c['currency'] ?? 'XOF');
    _notes    = TextEditingController(text: c['notes'] ?? '');
    _type     = c['type'] ?? 'cdi';
    if (c['end_date'] != null) {
      try { _end = DateTime.parse(c['end_date']); } catch (_) {}
    }
  }

  @override
  void dispose() { _salary.dispose(); _currency.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.updateContract(widget.contract['id'], {
        'type':     _type,
        'salary':   double.tryParse(_salary.text) ?? 0,
        'currency': _currency.text,
        'notes':    _notes.text,
        if (_end != null)
          'end_date': "${_end!.year}-${_end!.month.toString().padLeft(2,'0')}-${_end!.day.toString().padLeft(2,'0')}",
      });
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contrat mis à jour ✅'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Modifier le contrat',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type *'),
          items: _contractTypes.map((t) => DropdownMenuItem(
            value: t.toLowerCase(), child: Text(t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _salary,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Salaire *'))),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: TextField(controller: _currency,
            decoration: const InputDecoration(labelText: 'Devise'))),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event, size: 16),
          label: Text(_end == null ? 'Date de fin (CDI si vide)'
            : '\${_end!.day}/\${_end!.month}/\${_end!.year}'),
          onPressed: () async {
            final d = await showDatePicker(context: context,
              initialDate: _end ?? DateTime.now(),
              firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d != null) setState(() => _end = d);
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Enregistrer'),
        )),
      ])),
    );
  }
}