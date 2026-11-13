import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EmployeeDocumentsSection extends StatefulWidget {
  final int userId;
  final bool canUpload;
  final String title;

  const EmployeeDocumentsSection({
    super.key,
    required this.userId,
    this.canUpload = false,
    this.title = 'Documents administratifs',
  });

  @override
  State<EmployeeDocumentsSection> createState() =>
      _EmployeeDocumentsSectionState();
}

class _DocumentTitleDialog extends StatefulWidget {
  const _DocumentTitleDialog();

  @override
  State<_DocumentTitleDialog> createState() => _DocumentTitleDialogState();
}

class _DocumentTitleDialogState extends State<_DocumentTitleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Joindre un document'),
        content: TextField(
          controller: _controller,
          maxLength: 150,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Titre du document',
            hintText: 'Ex. Attestation de travail',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final title = _controller.text.trim();
              if (title.isNotEmpty) Navigator.pop(context, title);
            },
            child: const Text('Continuer'),
          ),
        ],
      );
}

class _EmployeeDocumentsSectionState extends State<EmployeeDocumentsSection> {
  List<dynamic> _documents = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents =
          await ApiService.getEmployeeDocuments(userId: widget.userId);
      if (mounted) setState(() => _documents = documents);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _DocumentTitleDialog(),
    );
    if (title == null || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ApiService.uploadEmployeeDocument(widget.userId, title, File(path));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document ajouté avec succès.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                error is ApiException ? error.fullMessage : error.toString()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    try {
      final bytes =
          await ApiService.downloadEmployeeDocument(document['id'] as int);
      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}/employee_document_${document['id']}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFile.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (widget.canUpload)
                IconButton(
                  onPressed: _uploading ? null : _upload,
                  tooltip: 'Joindre un PDF',
                  icon: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh),
              ),
            ]),
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_error!,
                    style: const TextStyle(color: AppTheme.danger)),
                trailing: IconButton(
                    onPressed: _load, icon: const Icon(Icons.refresh)),
              )
            else if (_documents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun document administratif disponible.',
                    style: TextStyle(color: AppTheme.textMuted)),
              )
            else
              ..._documents.map((item) {
                final document = item as Map<String, dynamic>;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined,
                      color: AppTheme.primary),
                  title: Text(document['title']?.toString() ?? ''),
                  subtitle: Text(document['original_name']?.toString() ?? ''),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openDocument(document),
                );
              }),
          ],
        ),
      ),
    );
  }
}
