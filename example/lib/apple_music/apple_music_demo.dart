/// Apple Music iOS 26 — High-Fidelity Demo
///
/// Animation architecture:
///   • `GlassSearchableBottomBar` uses `isSearchActive: _isMiniMode || _isSearching`
///     so the tabs spring-collapse whenever scrolled OR searching — matching the
///     iOS 26 morphing animation exactly.
///
///   • Two play bar pills work in concert:
///       1. Body-Stack pill   — full-width, floats ABOVE the nav bar when not mini.
///          On scroll it AnimatedPositioned DOWN to bar level + AnimatedOpacity 0.
///       2. NavBar-Stack pill — lives INSIDE the bottomNavigationBar SizedBox Stack
///          so it receives taps even in the nav-bar hit-test zone.  It AnimatedOpacity
///          fades IN when mini, always sitting at bar-pill level.
///
///     Together they create the illusion of "the bar collapses, the play pill slides
///     into the gap", with the handoff invisible to the user.
///
///   • A small search GlassButton is also inside the NavBar Stack at the right
///     edge — visible only in mini mode to match the iOS 26 [Home][Play][Search] row.
///
/// Run standalone:
///   flutter run -t lib/apple_music/apple_music_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kMusicRed = Color(0xFFFA2D48);
const _kBackground = Color(0xFF000000);
const _kCardGray = Color(0xFF2C2C2E);

const _kBarH = 64.0;
const _kPaddingH = 20.0;
const _kPaddingV = 16.0;
const _kSpacing = 8.0;

/// Glass shared by every pill (play bar, home icon, search icon).
const _kPillGlass = LiquidGlassSettings(
  glassColor: Color(0xCC1C1C1E),
  thickness: 30,
  blur: 3,
  lightIntensity: 0.35,
  chromaticAberration: .01,
);

// ─────────────────────────────────────────────────────────────────────────────
// APP
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(const AppleMusicDemoApp()));
}

class AppleMusicDemoApp extends StatelessWidget {
  const AppleMusicDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Music',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _kBackground,
        colorScheme: const ColorScheme.dark(
          primary: _kMusicRed,
          surface: _kBackground,
        ),
      ),
      home: const AppleMusicHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AppleMusicHomeScreen extends StatefulWidget {
  const AppleMusicHomeScreen({super.key});

  @override
  State<AppleMusicHomeScreen> createState() => _AppleMusicHomeScreenState();
}

class _AppleMusicHomeScreenState extends State<AppleMusicHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isMiniMode = false;
  bool _isSearching = false;
  bool _searchFieldFocused = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onScroll() {
    final mini = _scrollController.offset > 50;
    if (mini == _isMiniMode) return;
    setState(() {
      _isMiniMode = mini;
    });
  }

  void _onFocusChange() {
    setState(() => _searchFieldFocused = _searchFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  LiquidGlassSettings get _barGlassSettings => LiquidGlassSettings(
        glassColor: const Color(0xAA1C1C1E),
        thickness: 30,
        blur: 2,
        chromaticAberration: .01,
        lightAngle: GlassDefaults.lightAngle,
        lightIntensity: .5,
        ambientStrength: 0,
        refractiveIndex: 1.2,
        saturation: 1.2,
        specularSharpness: GlassSpecularSharpness.medium,
      );

  // ── Public actions ────────────────────────────────────────────────────────

  /// Called when user taps the collapsed home-tab pill in mini mode.
  void _dismissMiniMode() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
      );
    }
    setState(() {
      _isSearching = false;
      _searchFieldFocused = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Note: Since we don't use SafeArea, the bottom bar sits directly at the
    // physical screen bottom (overlapping the home indicator).
    // Since we removed SafeArea around GlassSearchableBottomBar, it sits exactly
    // at the absolute bottom of the screen (overlapping the home indicator).
    // The expanded height is `barHeight` (64) + 2 * `verticalPadding` (8).
    const double expandedNavBarH = 40 + 2 * _kPaddingV; // 80.0

    // aboveBarBottom: how far the floating play pill sits above the nav bar.
    // expandedNavBarH gets us to the TOP of the nav bar. We add 16.0 gap.
    final double aboveBarBottom = expandedNavBarH + 16.0;

    // miniBarBottom: position of the pill row inside the body Stack.
    // Since the nav bar is at the absolute bottom, its pills are exactly
    // `_kPaddingV` pixels from the bottom.
    final double miniBarBottom = _kPaddingV;

    // contentPad: extra bottom space so the last sliver scrolls above all bars.
    final double contentPad = aboveBarBottom + 50.0 + 8.0;

    // he sliding pill logic needs to know the exact dimensions of the
    // Home pill and the Search pill to shrink horizontally to fit between them.
    // The tabs pill width when collapsed is `_kBarH`.
    // The search pill width when expandWhenActive: false is `_kBarH`.
    // Both sides also have `_kSpacing` and `_kPaddingH`.
    final double miniPlayLeft = _kPaddingH + 50.0 + _kSpacing;
    final double miniPlayRight = _kPaddingH + 50.0 + _kSpacing;

    return Scaffold(
      backgroundColor: _kBackground,
      extendBody: true,
      resizeToAvoidBottomInset: false,

      // ── Bottom navigation bar ──────────────────────────────────────────────
      // GlassSearchableBottomBar natively handles the spring-collapse animation.
      // With expandWhenActive configured dynamically, the right-side search pill
      // does NOT expand across the screen when collapsing from a scroll, leaving
      // a natural gap in the middle for the Play pill to slide down into.
      bottomNavigationBar: GlassSearchableBottomBar(
        // KEY: triggers the beautiful spring tab-collapse on scroll TOO.
        isSearchActive: _isMiniMode || _isSearching,
        selectedIndex: _selectedTab,
        onTabSelected: (index) {
          if (index == _selectedTab && _isMiniMode) {
            _dismissMiniMode();
          } else {
            setState(() {
              _selectedTab = index;
              _isSearching = false;
            });
          }
        },
        barHeight: _kBarH,
        searchBarHeight: 50.0,
        horizontalPadding: _kPaddingH,
        verticalPadding: _kPaddingV,
        spacing: _kSpacing,
        selectedIconColor: _kMusicRed,
        unselectedIconColor: Colors.white.withValues(alpha: 0.9),
        indicatorColor: Colors.white.withValues(alpha: 0.20),
        labelFontSize: 10,
        iconSize: 28,
        iconLabelSpacing: 0,
        quality: GlassQuality.premium,
        interactionBehavior: GlassInteractionBehavior.full,
        glassSettings: _barGlassSettings,
        searchConfig: GlassSearchBarConfig(
          focusNode: _searchFocusNode,
          autoFocusOnExpand: false,
          showsCancelButton: true,
          // When in mini mode but NOT searching, prevent the search pill from expanding.
          expandWhenActive: !_isMiniMode || _isSearching,
          hintText: 'Apple Music',
          onSearchToggle: (active) {
            if (active) {
              setState(() => _isSearching = true);
            } else {
              final wasSearching = _isSearching;
              setState(() {
                _isSearching = false;
                _searchFieldFocused = false;
              });
              // Collapsed home-tab tapped in mini mode → scroll to top.
              if (!wasSearching && _isMiniMode) _dismissMiniMode();
            }
          },
          onSearchFocusChanged: (focused) =>
              setState(() => _searchFieldFocused = focused),
          searchIconColor: Colors.white.withValues(alpha: 0.9),
          textInputAction: TextInputAction.search,
        ),
        tabs: [
          GlassBottomBarTab(
            label: 'Home',
            icon: const Icon(CupertinoIcons.house),
            activeIcon: const Icon(CupertinoIcons.house_fill),
          ),
          GlassBottomBarTab(
            label: 'Radio',
            icon: const Icon(CupertinoIcons.antenna_radiowaves_left_right),
          ),
          GlassBottomBarTab(
            label: 'Library',
            icon: const Icon(CupertinoIcons.music_albums),
            activeIcon: const Icon(CupertinoIcons.music_albums_fill),
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              if (_searchFieldFocused) FocusScope.of(context).unfocus();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: !_isSearching
                  ? _buildHomeView(
                      key: const ValueKey('home'), contentPad: contentPad)
                  : _searchFieldFocused
                      ? _buildNoRecentSearches(key: const ValueKey('no-recent'))
                      : _buildSearchBrowseView(
                          key: const ValueKey('search-browse'),
                          contentPad: contentPad),
            ),
          ),

          // ── Body play pill ─────────────────────────────────────────────────
          // This is the ONLY play pill now. It stays fully visible and interactive.
          // In mini mode, it simply slides down into the empty gap left between
          // the Home and Search pills.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            bottom: _isMiniMode ? miniBarBottom : aboveBarBottom,
            left: _isMiniMode ? miniPlayLeft : _kPaddingH,
            right: _isMiniMode ? miniPlayRight : _kPaddingH,
            height: 50.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              // Only hide when the search UI overtakes the whole screen
              opacity: _isSearching ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _isSearching,
                child: _PlayBarPill(
                  onTap: () {
                    if (_isMiniMode) {
                      _dismissMiniMode();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page views ────────────────────────────────────────────────────────────

  Widget _buildHomeView({Key? key, required double contentPad}) {
    return CustomScrollView(
      key: key,
      controller: _selectedTab == 0 ? _scrollController : null,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).top + 8),
        ),
        SliverToBoxAdapter(child: _buildListenNowHeader()),
        SliverToBoxAdapter(
          child: _HeroCard(
            title: 'Music just for you.\n2 months free.',
            subtitle: 'Accept Free Trial',
            subtext: '2 months free, then \$12.99/month',
            color: _kMusicRed,
            child: const _AppleMusicLogo(),
          ),
        ),
        SliverToBoxAdapter(
          child: _HeroCard(
            title: 'Music for the whole\nfamily. 2 months free.',
            subtitle: 'Accept Free Trial',
            subtext: '2 months free, then \$19.99/month',
            color: _kCardGray,
            showBorder: true,
            child: const Icon(
              CupertinoIcons.person_3_fill,
              color: _kMusicRed,
              size: 240,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: contentPad)),
      ],
    );
  }

  Widget _buildListenNowHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Listen Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF4C4556),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'SD',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBrowseView({Key? key, required double contentPad}) {
    return CustomScrollView(
      key: key,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).top + 8),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.apple, color: Colors.white, size: 22),
                    SizedBox(width: 4),
                    Text(
                      'Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, contentPad),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _BrowseCategory(
                name: _kBrowseCategories[index].name,
                color: _kBrowseCategories[index].color,
              ),
              childCount: _kBrowseCategories.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoRecentSearches({Key? key}) {
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      key: key,
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardH + 50),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.search,
                    size: 64, color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(height: 16),
                const Text(
                  'No Recent Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your recent searches will appear here.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  const _Category({required this.name, required this.color});
  final String name;
  final Color color;
}

const _kBrowseCategories = [
  _Category(name: 'Pop', color: Color(0xFFFF2D55)),
  _Category(name: 'Hip-Hop', color: Color(0xFF5856D6)),
  _Category(name: 'Rock', color: Color(0xFF636366)),
  _Category(name: 'Electronic', color: Color(0xFF007AFF)),
  _Category(name: 'R&B / Soul', color: Color(0xFFAF52DE)),
  _Category(name: 'Country', color: Color(0xFFFF9500)),
  _Category(name: 'Jazz', color: Color(0xFF30B0C7)),
  _Category(name: 'Classical', color: Color(0xFF34C759)),
  _Category(name: 'Latin', color: Color(0xFFFF3B30)),
  _Category(name: 'Alternative', color: Color(0xFF1C1C1E)),
];

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Play bar pill — shared by the floating body pill and the mini NavBar pill.
class _PlayBarPill extends StatelessWidget {
  const _PlayBarPill({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onTap: onTap ?? () {},
      quality: GlassQuality.premium,
      useOwnLayer: true,
      shape: const LiquidRoundedSuperellipse(borderRadius: _kBarH / 2),
      settings: _kPillGlass,
      icon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB22222), Color(0xFF4A0000)],
                  ),
                ),
                child: const Icon(Icons.music_note,
                    color: Colors.white70, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            // Title + artist
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best of You',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Foo Fighters',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.play_arrow_solid,
                color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Icon(CupertinoIcons.forward_end_fill,
                color: Colors.white60, size: 20),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _AppleMusicLogo extends StatelessWidget {
  const _AppleMusicLogo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.apple, color: Colors.white, size: 56),
        Text(
          'Music',
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String subtext;
  final Color color;
  final Widget child;
  final bool showBorder;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.subtext,
    required this.color,
    required this.child,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 400,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const Spacer(),
          child,
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseCategory extends StatelessWidget {
  const _BrowseCategory({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: color,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(12),
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
