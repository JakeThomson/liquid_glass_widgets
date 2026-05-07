/// Apple Messages iOS 26 — GlassMenu Spring Physics Test Case
///
/// This is a high-fidelity clone of the iOS 26 Messages app, built
/// specifically to compare [GlassMenu] spring physics against the native
/// UIKit context menu implementation side-by-side on device.
///
/// Two menus are present — mirroring the real app:
///   • Top-left  "Edit" pill  → GlassMenu anchored topLeft
///     Items: Select Messages, Edit Pins, Set Up Name & Photo
///   • Top-right filter pill  → GlassMenu anchored topRight
///     Items: Messages (✓ checked), Spam, Recently Deleted, [divider], Manage Filtering
///
/// Run standalone:
///   flutter run -t lib/apple_messages/apple_messages_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE  (matches iOS 26 dark Messages)
// ─────────────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF000000);
const _kSeparator = Color(0x33FFFFFF); // ~20% white
const _kAvatarBg = Color(0xFF3A3A50); // muted indigo — iOS default avatar bg
const _kSearchBg = Color(0xFF1C1C1E);
const _kBlue = Color(0xFF0A84FF); // iOS 26 blue

// Glass shared by both menu triggers — matches the "Edit" pill aesthetic
const _kTriggerGlass = LiquidGlassSettings(
  glassColor: Color(0xBB1C1C1E),
  thickness: 28,
  blur: 14,
  lightIntensity: 0.3,
  ambientStrength: 0.15,
  chromaticAberration: 0.008,
  saturation: 1.1,
);

// Glass for the menus themselves (slightly more opaque than triggers)
const _kMenuGlass = LiquidGlassSettings(
  glassColor: Color(0xCC1C1C1E),
  thickness: 32,
  blur: 18,
  lightIntensity: 0.28,
  ambientStrength: 0.12,
  chromaticAberration: 0.006,
  saturation: 1.05,
);

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────

class _Conversation {
  const _Conversation({
    required this.name,
    required this.preview,
    required this.time,
    this.initial,
    this.isUnread = false,
    this.hasAttachment = false,
  });
  final String name;
  final String preview;
  final String time;
  final String? initial; // null → generic avatar icon
  final bool isUnread;
  final bool hasAttachment;
}

const _kConversations = [
  _Conversation(
    name: 'Mum',
    preview: 'Don\'t forget dinner on Sunday! 🍗',
    time: '5:41 pm',
    initial: 'M',
    isUnread: true,
  ),
  _Conversation(
    name: 'Work Group 💼',
    preview: 'Jake: Can everyone join the 3pm standup?',
    time: '4:56 pm',
    initial: 'W',
    isUnread: true,
  ),
  _Conversation(
    name: 'Alex',
    preview: 'You liked "Sounds good, see you there"',
    time: '11:06 am',
    initial: 'A',
  ),
  _Conversation(
    name: 'Priya',
    preview: 'Cheers! Safe travels 🙌',
    time: 'Tuesday',
    initial: 'P',
  ),
  _Conversation(
    name: 'Sam',
    preview: 'Attachment: 1 Photo',
    time: 'Tuesday',
    initial: 'S',
    hasAttachment: true,
  ),
  _Conversation(
    name: '+61 428 048 980',
    preview: 'Hi! Just a reminder your appointment is Fri 9 May at 2:30 PM. Reply STOP to opt out.',
    time: 'Monday',
  ),
  _Conversation(
    name: '+61 482 092 063',
    preview: 'Your parcel has been delivered to the front door. Track at auspost.com.au',
    time: 'Monday',
  ),
  _Conversation(
    name: 'Jordan',
    preview: 'haha yeah that was wild 😂',
    time: 'Monday',
    initial: 'J',
  ),
  _Conversation(
    name: 'Taylor',
    preview: 'Ok sounds good!',
    time: 'Sunday',
    initial: 'T',
  ),
  _Conversation(
    name: '+61 409 593 783',
    preview: 'Hi! FREE flu vaccines are now available for ALL ages at participating pharmacies near you.',
    time: 'Sunday',
  ),
  _Conversation(
    name: 'Riley',
    preview: 'The reservation is at 7:30, don\'t be late lol',
    time: 'Saturday',
    initial: 'R',
    isUnread: true,
  ),
  _Conversation(
    name: 'Westpac',
    preview: 'Your statement is ready. Log in to view.',
    time: 'Saturday',
  ),
  _Conversation(
    name: 'Casey',
    preview: 'Can you send me that recipe again?',
    time: 'Fri',
    initial: 'C',
  ),
  _Conversation(
    name: 'Fitness First',
    preview: 'Your class is confirmed for tomorrow at 6:45 AM. See you there!',
    time: 'Fri',
  ),
  _Conversation(
    name: 'Dad',
    preview: 'Call me when you get a chance mate',
    time: 'Thu',
    initial: 'D',
    isUnread: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// APP ENTRY
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — matches Messages on iPhone
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(
    child: const AppleMessagesDemoApp(),
    adaptiveQuality: true,
  ));
}

class AppleMessagesDemoApp extends StatelessWidget {
  const AppleMessagesDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messages',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _kBg,
        colorScheme: const ColorScheme.dark(
          primary: _kBlue,
          surface: _kBg,
        ),
      ),
      home: const _MessagesScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _MessagesScreen extends StatefulWidget {
  const _MessagesScreen();

  @override
  State<_MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<_MessagesScreen> {
  final _scrollController = ScrollController();
  bool _headerCollapsed = false;

  // Tracks which filter is selected in the right menu
  String _activeFilter = 'Messages';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final collapsed = _scrollController.hasClients && _scrollController.offset > 60;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Conversation list ────────────────────────────────────────────
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Status bar space + nav bar height
              SliverToBoxAdapter(child: SizedBox(height: topPad + 52)),

              // Large "Messages" title (collapses on scroll)
              SliverToBoxAdapter(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _headerCollapsed ? 0 : 1,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Conversation rows
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ConversationRow(
                    conversation: _kConversations[i],
                  ),
                  childCount: _kConversations.length,
                ),
              ),

              // Bottom padding — clears the search bar
              SliverToBoxAdapter(child: SizedBox(height: 90 + botPad)),
            ],
          ),

          // ── Top navigation bar ───────────────────────────────────────────
          _NavBar(
            topPad: topPad,
            headerCollapsed: _headerCollapsed,
            activeFilter: _activeFilter,
            onFilterChanged: (filter) => setState(() => _activeFilter = filter),
          ),

          // ── Bottom search + compose bar ──────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SearchBar(bottomPad: botPad),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.topPad,
    required this.headerCollapsed,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final double topPad;
  final bool headerCollapsed;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPad),
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Edit menu (top-left) ─────────────────────────────────
                  _EditMenu(),
                  const Spacer(),

                  // Inline "Messages" title when scrolled
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: headerCollapsed ? 1 : 0,
                    child: const Text(
                      'Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // ── Filter menu (top-right) ──────────────────────────────
                  _FilterMenu(
                    activeFilter: activeFilter,
                    onFilterChanged: onFilterChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT MENU  (top-left pill → opens downLeft)
// ─────────────────────────────────────────────────────────────────────────────

class _EditMenu extends StatelessWidget {
  const _EditMenu();

  @override
  Widget build(BuildContext context) {
    return GlassMenu(
      menuWidth: 230,
      glassSettings: _kMenuGlass,
      menuBorderRadius: 16,
      // Trigger: the "Edit" pill button
      trigger: GlassButton(
        onTap: () {}, // GlassMenu handles the tap via triggerBuilder
        quality: GlassQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: _kTriggerGlass,
        icon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Edit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
      items: [
        GlassMenuItem(
          title: 'Select Messages',
          icon: CupertinoIcons.checkmark_circle,
          onTap: () {},
        ),
        GlassMenuItem(
          title: 'Edit Pins',
          icon: CupertinoIcons.pin,
          onTap: () {},
        ),
        GlassMenuItem(
          title: 'Set Up Name & Photo',
          icon: CupertinoIcons.person_crop_circle,
          onTap: () {},
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER MENU  (top-right hamburger → opens downRight, has checkmark)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return GlassMenu(
      menuWidth: 240,
      glassSettings: _kMenuGlass,
      menuBorderRadius: 16,
      // Trigger: the hamburger circle pill
      trigger: GlassButton(
        onTap: () {},
        quality: GlassQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: _kTriggerGlass,
        icon: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      items: [
        GlassMenuItem(
          title: 'Messages',
          icon: CupertinoIcons.bubble_left_bubble_right,
          trailing: activeFilter == 'Messages'
              ? const Icon(CupertinoIcons.checkmark,
                  color: Colors.white, size: 16)
              : null,
          onTap: () => onFilterChanged('Messages'),
        ),
        GlassMenuItem(
          title: 'Spam',
          icon: CupertinoIcons.xmark_bin,
          trailing: activeFilter == 'Spam'
              ? const Icon(CupertinoIcons.checkmark,
                  color: Colors.white, size: 16)
              : null,
          onTap: () => onFilterChanged('Spam'),
        ),
        GlassMenuItem(
          title: 'Recently Deleted',
          icon: CupertinoIcons.trash,
          trailing: activeFilter == 'Recently Deleted'
              ? const Icon(CupertinoIcons.checkmark,
                  color: Colors.white, size: 16)
              : null,
          onTap: () => onFilterChanged('Recently Deleted'),
        ),
        const GlassMenuDivider(),
        GlassMenuItem(
          title: 'Manage Filtering',
          onTap: () {},
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});
  final _Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return GestureDetector(
      onTap: () {}, // no-op — this is a test fixture
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _Avatar(initial: c.initial, isUnread: c.isUnread),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: c.isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.time,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Preview
                      Text(
                        c.hasAttachment ? '📷  ${c.preview}' : c.preview,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Separator — indented to align with text (not avatar)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(height: 1, color: _kSeparator, thickness: 0.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({this.initial, required this.isUnread});
  final String? initial;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomLeft,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _kAvatarBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: initial != null
              ? Text(
                  initial!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(
                  CupertinoIcons.person_fill,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 26,
                ),
        ),
        // Unread blue dot
        if (isUnread)
          Positioned(
            left: -6,
            bottom: 14,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.bottomPad});
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Frosted glass background behind the search bar
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
          stops: const [0, 0.3, 0.7],
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad + 8),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _kSearchBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.search,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.mic,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Compose button
          GlassButton(
            onTap: () {},
            quality: GlassQuality.premium,
            shape: const LiquidRoundedSuperellipse(borderRadius: 22),
            settings: const LiquidGlassSettings(
              glassColor: Color(0xBB1C1C1E),
              thickness: 28,
              blur: 12,
              lightIntensity: 0.3,
              chromaticAberration: 0.008,
            ),
            icon: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                CupertinoIcons.square_pencil,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
