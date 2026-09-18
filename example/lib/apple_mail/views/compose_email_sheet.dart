import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/mail_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSE EMAIL SHEET (Liquid Morph-To-Full & Prominent tintColor Action)
// ─────────────────────────────────────────────────────────────────────────────

class ComposeEmailSheet extends StatefulWidget {
  const ComposeEmailSheet({
    super.key,
    required this.onSend,
    this.initialRecipient,
    this.initialSubject,
  });

  final void Function(String to, String subject, String body) onSend;
  final String? initialRecipient;
  final String? initialSubject;

  @override
  State<ComposeEmailSheet> createState() => _ComposeEmailSheetState();
}

class _ComposeEmailSheetState extends State<ComposeEmailSheet> {
  late final TextEditingController _toController;
  late final TextEditingController _subjectController;
  final TextEditingController _bodyController =
      TextEditingController(text: 'Sent from my iPhone');

  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _toController = TextEditingController(text: widget.initialRecipient ?? '');
    _subjectController =
        TextEditingController(text: widget.initialSubject ?? '');
    _toController.addListener(_validate);
    _subjectController.addListener(_validate);
    _validate();
  }

  void _validate() {
    final valid = _toController.text.trim().isNotEmpty;
    if (valid != _canSend) {
      setState(() => _canSend = valid);
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _attemptClose() {
    if (_toController.text.isNotEmpty || _subjectController.text.isNotEmpty) {
      GlassDialog.show(
        context: context,
        title: 'Save Draft?',
        message: 'Do you want to save this draft before closing?',
        actions: [
          GlassDialogAction(
            label: 'Delete Draft',
            isDestructive: true,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          GlassDialogAction(
            label: 'Save Draft',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          GlassDialogAction(
            label: 'Cancel',
            isPrimary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _send() {
    if (!_canSend) return;
    HapticFeedback.mediumImpact();
    widget.onSend(
      _toController.text.trim(),
      _subjectController.text.trim(),
      _bodyController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      color:
          isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sheet Grabber Handle
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF5A5A5E) : const Color(0xFFC7C7CC),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 8),

            // Top Bar: Cancel, New message, and Prominent tintColor Send Capsule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _attemptClose,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 17,
                        color: kMailBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'New message',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const Spacer(),

                  // Prominent Action tintColor send capsule
                  GlassButton.custom(
                    enabled: _canSend,
                    onTap: _send,
                    width: 32,
                    height: 32,
                    shape: const LiquidOval(),
                    glowColor: _canSend ? kMailBlue : null,
                    settings: LiquidGlassSettings(
                      glassColor:
                          _canSend ? kMailBlue : const Color(0xFF2C2C2E),
                      thickness: 10,
                      blur: 2,
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        size: 16,
                        color: _canSend
                            ? CupertinoColors.white
                            : CupertinoColors.inactiveGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 0.5, color: const Color(0xFF38383A)),

            // Compose Fields
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // To Field
                  _ComposeFieldRow(
                    label: 'To: ',
                    child: CupertinoTextField(
                      controller: _toController,
                      placeholder: 'Recipient',
                      placeholderStyle: const TextStyle(
                        color: Color(0xFF636366),
                        fontSize: 16,
                      ),
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontSize: 16,
                      ),
                      decoration: null,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  Container(height: 0.5, color: const Color(0xFF38383A)),

                  // Cc/Bcc/From
                  _ComposeFieldRow(
                    label: '',
                    child: Text(
                      'Cc/Bcc, From: alex@orion-labs.com',
                      style: TextStyle(
                        color: kMailSecondaryLabel.resolveFrom(context),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(height: 0.5, color: const Color(0xFF38383A)),

                  // Subject Field
                  _ComposeFieldRow(
                    label: 'Subject: ',
                    child: CupertinoTextField(
                      controller: _subjectController,
                      placeholder: 'Subject',
                      placeholderStyle: const TextStyle(
                        color: Color(0xFF636366),
                        fontSize: 16,
                      ),
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontSize: 16,
                      ),
                      decoration: null,
                    ),
                  ),
                  Container(height: 0.5, color: const Color(0xFF38383A)),
                  const SizedBox(height: 12),

                  // Message Body Field
                  CupertinoTextField(
                    controller: _bodyController,
                    placeholderStyle: const TextStyle(
                      color: Color(0xFF636366),
                      fontSize: 16,
                    ),
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 16,
                    ),
                    maxLines: 14,
                    minLines: 8,
                    decoration: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeFieldRow extends StatelessWidget {
  const _ComposeFieldRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: kMailSecondaryLabel.resolveFrom(context),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
