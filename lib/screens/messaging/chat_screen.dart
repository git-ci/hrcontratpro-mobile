import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  const ChatScreen({super.key, required this.partnerId, required this.partnerName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await ApiService.getMessages(widget.partnerId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs.cast<Map<String, dynamic>>());
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSilent() async {
    try {
      final msgs = await ApiService.getMessages(widget.partnerId);
      if (!mounted) return;
      final newMsgs = msgs.cast<Map<String, dynamic>>();
      if (newMsgs.length != _messages.length) {
        setState(() {
          _messages
            ..clear()
            ..addAll(newMsgs);
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier'),
            onTap: () {
              Navigator.pop(context);
              _showEditDialog(msg);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(msg);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> msg) {
    final ctrl = TextEditingController(text: msg['body'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty || text == msg['body']) { Navigator.pop(ctx); return; }
              Navigator.pop(ctx);
              try {
                final updated = await ApiService.editMessage(msg['id'] as int, text);
                if (!mounted) return;
                setState(() {
                  final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
                  if (idx != -1) _messages[idx] = updated;
                });
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Ce message sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.deleteMessage(msg['id'] as int);
                if (!mounted) return;
                setState(() => _messages.removeWhere((m) => m['id'] == msg['id']));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')));
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);

    // Optimistic UI
    final optimistic = {
      'id'         : -DateTime.now().millisecondsSinceEpoch,
      'sender_id'  : AuthService.user?['id'],
      'body'       : text,
      'created_at' : DateTime.now().toIso8601String(),
      '_pending'   : true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final sent = await ApiService.sendMessage(widget.partnerId, text);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == optimistic['id']);
        if (idx != -1) _messages[idx] = sent;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == optimistic['id']));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.user?['id'];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.accent.withOpacity(0.15),
            child: Text(
              widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Text(widget.partnerName, style: const TextStyle(fontSize: 16)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('Envoyez le premier message !',
                      style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg    = _messages[i];
                        final isMe   = msg['sender_id'] == me;
                        final pending = msg['_pending'] == true;
                        return _Bubble(
                          message: msg,
                          isMe: isMe,
                          pending: pending,
                          onLongPress: isMe && !pending
                              ? () => _showMessageOptions(msg)
                              : null,
                        );
                      },
                    ),
        ),
        _InputBar(ctrl: _ctrl, sending: _sending, onSend: _send),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool pending;
  final VoidCallback? onLongPress;
  const _Bubble({
    required this.message,
    required this.isMe,
    required this.pending,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final body    = message['body'] as String? ?? '';
    final time    = _fmtTime(message['created_at'] as String?);
    final edited  = message['edited_at'] != null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(body,
                style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14, height: 1.4)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (edited)
                Text('modifié · ',
                    style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMe ? Colors.white.withOpacity(0.55) : AppTheme.textMuted)),
              Text(time,
                  style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white.withOpacity(0.7) : AppTheme.textMuted)),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  pending ? Icons.access_time : Icons.done_all,
                  size: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  String _fmtTime(String? d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.sending, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with SingleTickerProviderStateMixin {
  bool _showEmoji = false;
  late final TabController _tabCtrl;

  static const _catIcons = ['😊', '👋', '❤️', '🎉', '🍕', '🌍'];
  static const List<List<String>> _catEmojis = [
    ['😀','😁','😂','🤣','😃','😄','😅','😆','😉','😊','😋','😎','😍','🥰','😘','🤩','😏','😒','😞','😔','😟','😕','🙁','😣','😖','😩','😢','😭','😤','😡','🤬','😳','😱','😨','😰','🥺','😐','😶','🙄','😬','🤔','🤗','😴','🥱','🤒','🤕','😷'],
    ['👍','👎','👌','🤞','✌️','🤟','🤘','🙏','👏','🤝','💪','👋','🖐️','✋','🤜','🤛','💅','🫶','👐','🤲','🫂'],
    ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','💕','💞','💓','💗','💖','💘','💝','💟','❣️'],
    ['🎉','🎊','🎈','🎁','🎀','🎆','🎇','✨','🌟','⭐','💫','🔥','🏆','🥇','🎯','🎮','🎲','🎭','🎬','🎤','🎵','🎶','🥳'],
    ['🍕','🍔','🌮','🌯','🥗','🍜','🍝','🍣','🍱','🍛','🥘','🍲','🍟','🌭','🥙','🍗','🍖','🍳','🥞','🧇','🍰','🎂','🍩','🍪','🍫','🍭','🥤','☕','🍺','🍷','🥂'],
    ['🌸','🌺','🌹','🌷','🌻','💐','🍀','🌿','🌱','🌲','🌴','🍃','🐶','🐱','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐸','🦋','🌊','🌈','🌙','☀️','❄️','⛅'],
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _catIcons.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _toggleEmoji() {
    if (!_showEmoji) FocusScope.of(context).unfocus();
    setState(() => _showEmoji = !_showEmoji);
  }

  void _insertEmoji(String emoji) {
    final text  = widget.ctrl.text;
    final sel   = widget.ctrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end   = sel.end   < 0 ? text.length : sel.end;
    widget.ctrl.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kbBottom = _showEmoji ? 0.0 : MediaQuery.of(context).viewInsets.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: kbBottom + 8),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            IconButton(
              icon: Icon(_showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined),
              color: _showEmoji ? AppTheme.primary : AppTheme.textMuted,
              onPressed: _toggleEmoji,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: widget.ctrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onTap: () { if (_showEmoji) setState(() => _showEmoji = false); },
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.sending ? null : widget.onSend,
              icon: widget.sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              color: AppTheme.primary,
              style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  shape: const CircleBorder()),
            ),
          ]),
        ),
        if (_showEmoji) _EmojiPanel(
          tabCtrl:     _tabCtrl,
          catIcons:    _catIcons,
          catEmojis:   _catEmojis,
          onEmojiTap:  _insertEmoji,
        ),
      ],
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  final TabController tabCtrl;
  final List<String> catIcons;
  final List<List<String>> catEmojis;
  final void Function(String) onEmojiTap;

  const _EmojiPanel({
    required this.tabCtrl,
    required this.catIcons,
    required this.catEmojis,
    required this.onEmojiTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    color: Colors.white,
    child: Column(children: [
      TabBar(
        controller: tabCtrl,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: catIcons.map((ic) =>
          Tab(child: Text(ic, style: const TextStyle(fontSize: 18)))
        ).toList(),
      ),
      Expanded(
        child: TabBarView(
          controller: tabCtrl,
          children: List.generate(catIcons.length, (ci) {
            final emojis = catEmojis[ci];
            return GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => onEmojiTap(emojis[i]),
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: Text(emojis[i], style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }),
        ),
      ),
    ]),
  );
}
