import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/checkin_reminder_service.dart';
import '../../theme/app_theme.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _processing = false;
  bool _done = false;
  String? _message;
  bool _success = false;

  // Onglet actif : 'scan' ou 'matricule'
  String _tab = 'scan';
  final _matriculeCtrl = TextEditingController();

  // Payload mémorisé pour le mode matricule
  String? _lastPayload;
  String? _lastSignature;

  @override
  void dispose() {
    _controller.dispose();
    _matriculeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _processing = true);

    try {
      String? payload, signature;

      if (code.startsWith('http')) {
        try {
          final uri = Uri.parse(code);
          payload = uri.queryParameters['payload'];
          signature = uri.queryParameters['sig'];

          // URL courte (/s/token) : résoudre la redirection pour obtenir payload et sig
          if ((payload == null || signature == null) && code.contains('/s/')) {
            final resolved = await _resolveShortUrl(code);
            payload = resolved['payload'];
            signature = resolved['sig'];
          }
        } catch (_) {}
      }

      if (payload == null || signature == null) {
        setState(() {
          _message = 'QR code invalide.';
          _processing = false;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _message = null);
        });
        return;
      }

      // Mode matricule → mémoriser le payload et basculer sur la saisie
      if (_tab == 'matricule') {
        setState(() {
          _lastPayload = payload;
          _lastSignature = signature;
          _processing = false;
          _message = '✅ QR scanné ! Saisissez votre matricule.';
        });
        return;
      }

      // Mode scan normal → pointer directement
      await _controller.stop();
      final result = await ApiService.scanQr(payload, signature);
      CheckinReminderService.cancelReminders();
      setState(() {
        _done = true;
        _success = true;
        _message = result['message'] ?? 'Présence enregistrée !';
      });
    } catch (e) {
      final msg = e.toString();
      // Garder _processing = true pour bloquer de nouveaux scans pendant l'affichage
      setState(() {
        _message = msg;
        _processing = true;
      });
      // Messages métier importants → 10 s, erreurs courtes → 4 s
      final isImportant = msg.contains('arrivée') ||
          msg.contains('départ') ||
          msg.contains('déjà') ||
          msg.contains('téléphone') ||
          msg.contains('refusé');
      await Future.delayed(Duration(seconds: isImportant ? 10 : 4));
      if (mounted) setState(() {
        _message = null;
        _processing = false;
      });
    }
  }

  Future<Map<String, String?>> _resolveShortUrl(String shortUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(shortUrl));
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      client.close();
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null) {
        final uri = Uri.parse(location);
        return {
          'payload': uri.queryParameters['payload'],
          'sig': uri.queryParameters['sig'],
        };
      }
    } catch (_) {}
    return {'payload': null, 'sig': null};
  }

  Future<void> _submitMatricule() async {
    final mat = _matriculeCtrl.text.trim().toUpperCase();
    if (mat.isEmpty) {
      setState(() => _message = 'Saisissez votre matricule.');
      return;
    }
    if (_lastPayload == null || _lastSignature == null) {
      setState(() => _message = 'Scannez d\'abord le QR code.');
      return;
    }
    setState(() => _processing = true);
    try {
      final result =
          await ApiService.scanMatricule(mat, _lastPayload!, _lastSignature!);
      setState(() {
        _done = true;
        _success = true;
        _message = result['message'] ?? 'Présence enregistrée !';
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _message = msg;
        _processing = false;
      });
      final isImportant = msg.contains('arrivée') ||
          msg.contains('départ') ||
          msg.contains('déjà') ||
          msg.contains('téléphone') ||
          msg.contains('refusé');
      await Future.delayed(Duration(seconds: isImportant ? 10 : 4));
      if (mounted) setState(() => _message = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.role ?? 'employee';
    final prefix = role == 'employee' ? 'emp' : role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 Pointer ma présence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/$prefix/attendance'),
        ),
      ),
      body: _done ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildScanner() => Column(children: [
        // ── Onglets ─────────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: Row(children: [
            _TabButton(
                label: '📷 Scanner',
                active: _tab == 'scan',
                onTap: () => setState(() {
                      _tab = 'scan';
                      _message = null;
                    })),
            _TabButton(
                label: '🪪 Matricule',
                active: _tab == 'matricule',
                onTap: () => setState(() {
                      _tab = 'matricule';
                      _message = null;
                    })),
          ]),
        ),

        // ── Caméra ──────────────────────────────────────────────────────────────
        SizedBox(
          height: 280,
          child: Stack(children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            // Coins de scan
            Positioned.fill(child: CustomPaint(painter: _ScanOverlay())),
            if (_processing)
              Container(
                  color: Colors.black45,
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.white))),
          ]),
        ),

        // ── Message statut ───────────────────────────────────────────────────────
        if (_message != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _message!.startsWith('✅')
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _message!.startsWith('✅')
                      ? AppTheme.success.withOpacity(0.3)
                      : AppTheme.danger.withOpacity(0.3)),
            ),
            child: Text(_message!,
                style: TextStyle(
                    color: _message!.startsWith('✅')
                        ? AppTheme.success
                        : AppTheme.danger,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ),

        // ── Panneau matricule ────────────────────────────────────────────────────
        if (_tab == 'matricule')
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: _matriculeCtrl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3),
                decoration: const InputDecoration(
                  labelText: 'Numéro Matricule',
                  hintText: 'EMP-001',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _submitMatricule,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider le pointage'),
                ),
              ),
            ]),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Placez le QR code du terminal devant la caméra.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ),
      ]);

  Widget _buildResult() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(_success ? Icons.check_circle : Icons.error,
                size: 80, color: _success ? AppTheme.success : AppTheme.danger),
            const SizedBox(height: 20),
            Text(_success ? 'Présence enregistrée !' : 'Erreur',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                final role = AuthService.role ?? 'employee';
                final prefix = role == 'employee' ? 'emp' : role;
                context.go('/$prefix/attendance');
              },
              child: const Text('Retour'),
            ),
          ]),
        ),
      );
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: active ? AppTheme.primary : Colors.transparent,
                      width: 2)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: active ? AppTheme.primary : AppTheme.textMuted)),
          ),
        ),
      );
}

class _ScanOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const l = 30.0;
    final corners = [
      const Offset(20, 20),
      Offset(size.width - 20, 20),
      Offset(20, size.height - 20),
      Offset(size.width - 20, size.height - 20),
    ];
    for (final c in corners) {
      final dx = c.dx < size.width / 2 ? 1.0 : -1.0;
      final dy = c.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(c, Offset(c.dx + dx * l, c.dy), paint);
      canvas.drawLine(c, Offset(c.dx, c.dy + dy * l), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
