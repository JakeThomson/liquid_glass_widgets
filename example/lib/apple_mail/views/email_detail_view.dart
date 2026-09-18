import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/mail_models.dart';
import '../theme/mail_theme.dart';
import 'compose_email_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL DETAIL VIEW (Message View with Pinned Triage Bar & Reply Menu)
// ─────────────────────────────────────────────────────────────────────────────

class EmailDetailView extends StatelessWidget {
  const EmailDetailView({
    super.key,
    required this.item,
    required this.onDelete,
  });

  final MailItem item;
  final VoidCallback onDelete;

  void _openReplySheet(
    BuildContext context,
    String prefix,
    GlassMorphAnchor? anchor,
  ) {
    GlassModalSheet.show(
      context: context,
      morphFrom: anchor,
      initialState: GlassSheetState.full,
      builder: (sheetContext) => ComposeEmailSheet(
        initialRecipient: item.sender,
        initialSubject: '$prefix: ${item.subject}',
        onSend: (to, subject, body) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: ColoredBox(color: kMailBg.resolveFrom(context)),
      appBar: GlassAppBar.pinned(
        buttonSettings: kMailTriggerGlass(context),
        title: Text(
          item.sender,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          GlassBarItem.icon(
            id: 'detail_trash',
            icon: const Icon(CupertinoIcons.trash, size: 18),
            onTap: onDelete,
          ),
          GlassBarItem.icon(
            id: 'detail_flag',
            icon: const Icon(CupertinoIcons.flag, size: 18),
            onTap: () => HapticFeedback.selectionClick(),
          ),
          // Follows Jake's PR #325: morphs out of the pinned bar capsule
          // while GlassNavigationShell keeps the emptied capsule hoisted.
          GlassBarItem.sheet(
            id: 'detail_reply',
            icon: const Icon(CupertinoIcons.reply, size: 18),
            onPresent: (anchor) => _openReplySheet(context, 'Re', anchor),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const SizedBox(height: 48),

          // Sender Row with Avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.avatarColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: item.avatarType == AvatarType.store
                      ? Icon(
                          CupertinoIcons.bag_fill,
                          color: item.avatarColor,
                          size: 20,
                        )
                      : Text(
                          item.initials ?? '?',
                          style: TextStyle(
                            color: item.avatarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.sender,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    Text(
                      'to: alex@orion-labs.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: kMailSecondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item.time,
                style: TextStyle(
                  fontSize: 13,
                  color: kMailSecondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subject Line
          Text(
            item.subject,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 16),

          // Attachment Chip (if present)
          if (item.hasAttachment) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.doc_fill,
                      size: 16,
                      color: kMailBlue,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'spec_overview_v1.pdf',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(2.4 MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(height: 0.5, color: const Color(0xFF2C2C2E)),
          const SizedBox(height: 16),

          // Body text
          Text(
            item.body ?? item.snippet,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
