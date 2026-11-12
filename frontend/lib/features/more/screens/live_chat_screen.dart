import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/wizzcentral_support_chat_service.dart';
import '../../../services/support_conversation_store.dart';
import '../../../services/support_chat_identity.dart';
import '../../../widgets/support_attachment_image.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen(
      {super.key, this.initialTopic, this.identitySource, this.chatFactory});
  final String? initialTopic;
  @visibleForTesting
  final SupportChatIdentitySource? identitySource;
  @visibleForTesting
  final WizzCentralSupportChatService Function(SupportDriverIdentity)?
      chatFactory;
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  late final SupportChatIdentitySource _identity;
  StreamSubscription<void>? _authSubscription;
  WizzCentralSupportChatService? _chat;
  int _epoch = 0;
  bool _loading = true;
  String? _identityError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _identity = widget.identitySource ?? AmplifySupportChatIdentitySource();
    _authSubscription = _identity.invalidations
        .listen((_) => _invalidate(), onError: (Object _) => _invalidate());
    unawaited(_open());
  }

  void _clearChat() {
    final chat = _chat;
    _chat = null;
    chat?.removeListener(_changed);
    chat?.dispose();
    _text.clear();
  }

  void _invalidate() {
    ++_epoch;
    _clearChat();
    if (mounted) {
      setState(() {
        _loading = false;
        _identityError = 'تغيرت جلسة الدخول. تحقق من الحساب ثم أعد المحاولة.';
      });
    }
  }

  Future<void> _open() async {
    final epoch = ++_epoch;
    _clearChat();
    setState(() {
      _loading = true;
      _identityError = null;
    });
    try {
      final owner = await _identity.read().timeout(const Duration(seconds: 15));
      if (!mounted || epoch != _epoch) return;
      if (owner == null) {
        setState(() {
          _loading = false;
          _identityError = 'سجّل الدخول إلى حسابك للتواصل مع الدعم.';
        });
        return;
      }
      final chat = widget.chatFactory?.call(owner) ??
          WizzCentralSupportChatService(
              tokenProvider: () => _identity.tokenFor(owner.subject),
              driverName: owner.name,
              initialTopic: widget.initialTopic,
              store: SecureSupportConversationStore(
                  ownerId: owner.subject,
                  endpoint: WizzCentralSupportChatService.defaultEndpoint));
      _chat = chat;
      chat.addListener(_changed);
      setState(() => _loading = false);
      await chat.connect();
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _loading = false;
          _identityError = 'تعذر التحقق من جلسة الدخول. حاول مجددًا.';
        });
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    final draft = _chat?.draft ?? '';
    if (_text.text != draft) {
      _text.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length));
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final chat = _chat;
    if (state == AppLifecycleState.resumed &&
        chat != null &&
        !chat.ready &&
        !chat.connecting &&
        !chat.closed &&
        !chat.closing) {
      unawaited(chat.connect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_epoch;
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    _clearChat();
    _text.dispose();
    super.dispose();
  }

  bool _pickingImage = false;
  Future<void> _pickImage() async {
    final chat = _chat;
    if (_pickingImage || chat == null || !chat.ready || chat.closing) return;
    setState(() => _pickingImage = true);
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (!mounted || _chat != chat || selected == null) return;
      if (await selected.length() >
          WizzCentralSupportChatService.maxImageBytes) {
        throw StateError('Image too large');
      }
      final bytes = await selected.readAsBytes();
      if (!mounted || _chat != chat) return;
      await chat.sendImage(bytes, _text.text);
    } catch (_) {
      if (mounted && _chat == chat) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر اختيار الصورة. اختر JPEG أو PNG بحجم لا يتجاوز ٢ ميغابايت.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('الدردشة مع الدعم'),
          actions: [
            if (chat != null && chat.closed)
              TextButton(
                onPressed: chat.startNewConversation,
                child: const Text('محادثة جديدة'),
              ),
            if (chat != null && chat.ready && !chat.closed)
              TextButton(
                onPressed: chat.closing
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('إنهاء المحادثة؟'),
                            content: const Text(
                              'يمكنك بدء محادثة جديدة لاحقًا.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('رجوع'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('إنهاء'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          chat.endConversation();
                        }
                      },
                child: Text(chat.closing ? 'جارٍ الإنهاء…' : 'إنهاء'),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : chat == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_identityError ??
                        'سجّل الدخول إلى حسابك للتواصل مع الدعم.'),
                    TextButton(
                        onPressed: _open, child: const Text('إعادة المحاولة')),
                  ]))
                : Column(
                    children: [
                      if (chat.connecting) const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          chat.closed
                              ? 'انتهت المحادثة'
                              : chat.ready
                                  ? 'يمكنك مراسلة فريق الدعم'
                                  : 'بانتظار الاتصال بالدعم',
                        ),
                      ),
                      if (chat.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(child: Text(chat.error!)),
                              if (!chat.closed &&
                                  !chat.connecting &&
                                  !chat.ready)
                                TextButton(
                                  onPressed: chat.connect,
                                  child: const Text('إعادة الاتصال'),
                                ),
                            ],
                          ),
                        ),
                      if (chat.loadingHistory) const LinearProgressIndicator(),
                      if (chat.historyError != null)
                        TextButton(
                          onPressed: chat.retryHistory,
                          child: Text(chat.historyError!),
                        ),
                      if (chat.nextCursor != null && chat.historyError == null)
                        TextButton(
                          onPressed: chat.loadingHistory || !chat.ready
                              ? null
                              : chat.loadOlder,
                          child: const Text('تحميل الرسائل الأقدم'),
                        ),
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: chat.messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                chat.messages[chat.messages.length - index - 1];
                            return Align(
                              alignment: message.sender == 'driver'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                color: message.sender == 'driver'
                                    ? const Color(0xFF00296B)
                                    : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        message.sender == 'driver'
                                            ? 'أنت'
                                            : 'فريق الدعم',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                              color: message.sender == 'driver'
                                                  ? Colors.white
                                                  : const Color(0xFF00296B),
                                            ),
                                      ),
                                      SelectableText(message.text,
                                          style: TextStyle(
                                              color: message.sender == 'driver'
                                                  ? Colors.white
                                                  : const Color(0xFF00296B))),
                                      if (message.isUploading)
                                        const Text('جارٍ رفع الصورة…'),
                                      if (message.attachmentId != null)
                                        SupportAttachmentImage(
                                          foregroundColor:
                                              message.sender == 'driver'
                                                  ? Colors.white
                                                  : const Color(0xFF00296B),
                                          key: ValueKey(
                                            '${chat.sessionId}:${message.attachmentId}',
                                          ),
                                          load: () => chat.loadImage(
                                            message.attachmentId!,
                                          ),
                                        ),
                                      if (message.sender == 'driver')
                                        Text(
                                          switch (message.status) {
                                            'accepted' => 'تم الحفظ',
                                            'unknown' => 'لم يتأكد الإرسال',
                                            'failed' => 'تعذر الإرسال',
                                            _ => 'جارٍ الإرسال…',
                                          },
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
                                                color: message.sender ==
                                                        'driver'
                                                    ? Colors.white
                                                    : const Color(0xFF00296B),
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (!chat.closed)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _text,
                                    maxLength: 4000,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: 'اكتب رسالتك',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) => chat.draft = value,
                                  ),
                                ),
                                if (chat.imagesAvailable)
                                  IconButton(
                                    tooltip: 'إرفاق صورة',
                                    onPressed: chat.ready &&
                                            !chat.closing &&
                                            !_pickingImage
                                        ? _pickImage
                                        : null,
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'إرسال',
                                  onPressed: chat.ready && !chat.closing
                                      ? () {
                                          if (chat.send(_text.text)) {
                                            _text.clear();
                                          }
                                        }
                                      : null,
                                  icon: const Icon(Icons.send),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
