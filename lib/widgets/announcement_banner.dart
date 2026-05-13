import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnnouncementBanner — bandeau défilant persistant (toutes les pages sauf messages)
// ─────────────────────────────────────────────────────────────────────────────
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  List<Map<String, dynamic>> _announcements = [];
  int _current = 0;
  int _runId = 0;
  Timer? _pollTimer;

  static const _styles = {
    'info':     _Style(bg: Color(0xFFe7f5ff), text: Color(0xFF1864ab), icon: 'ℹ️'),
    'warning':  _Style(bg: Color(0xFFfff3bf), text: Color(0xFF7a5000), icon: '⚠️'),
    'sanction': _Style(bg: Color(0xFFffe3e3), text: Color(0xFFc92a2a), icon: '🚨'),
  };

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw  = await ApiService.getAnnouncements();
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(raw);
      setState(() {
        _announcements = list;
        if (_current >= list.length) _current = 0;
      });
    } catch (_) {}
  }

  void _advance() {
    if (!mounted || _announcements.isEmpty) return;
    setState(() {
      _current = (_current + 1) % _announcements.length;
      _runId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_announcements.isEmpty) return const SizedBox.shrink();

    final ann    = _announcements[_current];
    final type   = (ann['type'] as String?) ?? 'info';
    final style  = _styles[type] ?? _styles['info']!;
    final sender = (ann['sender'] as Map?)?['name'] as String? ?? '';
    final title  = (ann['title'] as String?) ?? '';
    final body   = (ann['body']  as String?) ?? '';
    final label  = title.isNotEmpty
        ? '$title${body.isNotEmpty ? "  —  $body" : ""}'
        : body;

    return Container(
      height: 32,
      color: style.bg,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(style.icon, style: const TextStyle(fontSize: 13, height: 1)),
          const SizedBox(width: 5),
          if (sender.isNotEmpty)
            Text(
              '$sender : ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.text,
                height: 1,
              ),
            ),
          Expanded(
            child: _MarqueeText(
              key: ValueKey(_runId),
              text: label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: style.text,
              ),
              onComplete: _advance,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Config par type ───────────────────────────────────────────────────────────
class _Style {
  final Color bg;
  final Color text;
  final String icon;
  const _Style({required this.bg, required this.text, required this.icon});
}

// ── Texte défilant ────────────────────────────────────────────────────────────
class _MarqueeText extends StatefulWidget {
  final String       text;
  final TextStyle    style;
  final VoidCallback onComplete;

  const _MarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.onComplete,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  TextPainter? _tp;
  double _textWidth = 0;
  double _textHeight = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) widget.onComplete();
          });
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _ctrl.duration = Duration(seconds: (tp.width / 55).clamp(8.0, 25.0).round());
    setState(() {
      _tp = tp;
      _textWidth = tp.width;
      _textHeight = tp.height;
    });
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_tp == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (_, constraints) {
        final cw = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _MarqueePainter(
              tp: _tp!,
              dx: cw - _ctrl.value * (cw + _textWidth),
              textHeight: _textHeight,
            ),
            size: Size(cw, _textHeight),
          ),
        );
      },
    );
  }
}

class _MarqueePainter extends CustomPainter {
  final TextPainter tp;
  final double dx;
  final double textHeight;

  _MarqueePainter({required this.tp, required this.dx, required this.textHeight});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    tp.paint(canvas, Offset(dx, (size.height - textHeight) / 2));
  }

  @override
  bool shouldRepaint(_MarqueePainter old) => old.dx != dx;
}
