/// Apple News iOS 26 — High-Fidelity Demo
///
/// Replicates the Apple News app layout with a real GlassBottomBar
/// using the new morphing search feature.
///
/// Run standalone: `flutter run -t lib/apple_news/apple_news_demo.dart`
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kNewsRed = Color(0xFFFF2D55);
const _kLiveBadge = Color(0xFFFF3B30);
const _kBackground = Color(0xFF000000);
const _kCardBackground = Color(0xFF1C1C1E);
const _kSeparator = Color(0xFF38383A);

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _Article {
  const _Article({
    required this.headline,
    required this.publication,
    required this.imageAsset,
    this.isLive = false,
    this.hasTopStoriesBadge = false,
    this.moreCoverage = false,
  });

  final String headline;
  final String publication;
  final String imageAsset;
  final bool isLive;
  final bool hasTopStoriesBadge;
  final bool moreCoverage;
}

class _TopicCategory {
  const _TopicCategory({
    required this.name,
    required this.color,
    required this.imageAsset,
  });

  final String name;
  final Color color;
  final String imageAsset;
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────

const _kTopStories = [
  _Article(
    headline:
        'Tehran warns US over Strait of Hormuz threat; Netanyahu suggests Israel helped rescue airman',
    publication: 'The Guardian',
    imageAsset: 'assets/news_images/tehran_guardian.jpg',
    // isLive: true,
    hasTopStoriesBadge: true,
    moreCoverage: true,
  ),
  _Article(
    headline:
        'Markets surge after Fed signals three rate cuts this year despite persistent inflation',
    publication: 'The Wall Street Journal',
    imageAsset: 'assets/news_images/markets_wsj.jpg',
    moreCoverage: true,
  ),
  _Article(
    headline:
        'Apple announces spatial computing breakthrough at WWDC, Vision Pro 2 coming this fall',
    publication: 'Bloomberg',
    imageAsset: 'assets/news_images/apple_bloomberg.jpg',
  ),
];

const _kMoreArticles = [
  _Article(
    headline:
        'Scientists discover potential link between gut microbiome and Alzheimer\'s disease risk',
    publication: 'Nature',
    imageAsset: 'assets/news_images/science_nature.jpg',
  ),
  _Article(
    headline:
        'UEFA Champions League: Real Madrid face Arsenal in stunning semi-final clash',
    publication: 'BBC Sport',
    imageAsset: 'assets/news_images/soccer_bbc.jpg',
  ),
  _Article(
    headline:
        'Climate summit reaches historic agreement on carbon emissions targets ahead of 2030 deadline',
    publication: 'Reuters',
    imageAsset: 'assets/news_images/climate_reuters.jpg',
    isLive: true,
  ),
  _Article(
    headline:
        'New AI model writes code faster than senior engineers, raising questions about the future of work',
    publication: 'MIT Technology Review',
    imageAsset: 'assets/news_images/ai_mit.jpg',
  ),
  _Article(
    headline:
        'SpaceX Starship completes first fully successful orbital flight and ocean landing',
    publication: 'The Verge',
    imageAsset: 'assets/news_images/spacex_verge.jpg',
  ),
];

const _kTopics = [
  _TopicCategory(
    name: 'Sport',
    color: Color(0xFF34C759),
    imageAsset: 'assets/news_images/topic_sport.jpg',
  ),
  _TopicCategory(
    name: 'Entertainment',
    color: Color(0xFFFF3B30),
    imageAsset: 'assets/news_images/topic_entertainment.jpg',
  ),
  _TopicCategory(
    name: 'Business',
    color: Color(0xFF007AFF),
    imageAsset: 'assets/news_images/topic_business.jpg',
  ),
  _TopicCategory(
    name: 'Politics',
    color: Color(0xFF3A3A3C),
    imageAsset: 'assets/news_images/topic_politics.jpg',
  ),
  _TopicCategory(
    name: 'Food',
    color: Color(0xFFFFCC02),
    imageAsset: 'assets/news_images/topic_food.jpg',
  ),
  _TopicCategory(
    name: 'Health',
    color: Color(0xFFFF9500),
    imageAsset: 'assets/news_images/topic_health.jpg',
  ),
  _TopicCategory(
    name: 'Lifestyle',
    color: Color(0xFF30B0C7),
    imageAsset: 'assets/news_images/topic_lifestyle.jpg',
  ),
  _TopicCategory(
    name: 'Science',
    color: Color(0xFFAF52DE),
    imageAsset: 'assets/news_images/topic_science.jpg',
  ),
  _TopicCategory(
    name: 'Climate',
    color: Color(0xFF636366),
    imageAsset: 'assets/news_images/topic_climate.jpg',
  ),
  _TopicCategory(
    name: 'Cars',
    color: Color(0xFF3634A3),
    imageAsset: 'assets/news_images/topic_cars.jpg',
  ),
  _TopicCategory(
    name: 'Home & Garden',
    color: Color(0xFF34C759),
    imageAsset: 'assets/news_images/topic_garden.jpg',
  ),
  _TopicCategory(
    name: 'Travel',
    color: Color(0xFF30B0C7),
    imageAsset: 'assets/news_images/topic_travel.jpg',
  ),
];

const _kCategories = [
  'Sport',
  'Business',
  'Food',
  'Entertainment',
  'Health',
  'Science',
  'Climate',
];

// ─────────────────────────────────────────────────────────────────────────────
// APP ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(const AppleNewsDemoApp()));
}

class AppleNewsDemoApp extends StatelessWidget {
  const AppleNewsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple News',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _kBackground,
        colorScheme: const ColorScheme.dark(
          primary: _kNewsRed,
          surface: _kBackground,
        ),
      ),
      home: const AppleNewsHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AppleNewsHomeScreen extends StatefulWidget {
  const AppleNewsHomeScreen({super.key});

  @override
  State<AppleNewsHomeScreen> createState() => _AppleNewsHomeScreenState();
}

class _AppleNewsHomeScreenState extends State<AppleNewsHomeScreen> {
  bool _isSearching = false;
  int _selectedTab = 0; // 0=Today, 1=News+, 2=Audio, 3=Following

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      extendBody: true, // Content flows behind the bottom bar
      // Keep false so the bar can manage its own keyboard inset via the
      // AnimatedPadding below — prevents the body from being double-inset.
      resizeToAvoidBottomInset: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _isSearching
            ? _buildSearchView(key: const ValueKey('search'))
            : _buildTodayView(key: const ValueKey('today')),
      ),
      // ── GlassSearchableBottomBar: tabs + morphing search in one layer ─────────
      // AnimatedPadding lifts the bar above the keyboard when it opens.
      // viewInsets.bottom is 0 when keyboard is hidden and the keyboard
      // height (e.g. ~336 pt) when it is visible, so the bar smoothly
      // rides up with the IME rather than being obscured by it.
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: GlassSearchableBottomBar(
          selectedIndex: _selectedTab,
          isSearchActive: _isSearching,
          onTabSelected: (index) => setState(() {
            _selectedTab = index;
            _isSearching = false;
          }),
          selectedIconColor: Color.fromRGBO(255, 90, 130, 1),
          unselectedIconColor: Colors.white.withValues(alpha: 0.9),
          labelFontSize: 10,
          iconSize: 28,
          iconLabelSpacing: 0,
          // Neutral frosted-glass pill. AnimatedGlassIndicator now renders
          // this value directly without any hidden multiplier.
          indicatorColor: Colors.white.withValues(alpha: 0.16),
          quality: GlassQuality.premium,
          glassSettings: LiquidGlassSettings(
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
          ),
          // ── Search bar config ───────────────────────────────────────────────
          searchConfig: GlassSearchBarConfig(
            hintText: 'Apple News',
            collapsedTabWidth: 64,
            onSearchToggle: (active) => setState(() => _isSearching = active),
            searchIconColor: Colors.white.withValues(alpha: 0.9),
            textInputAction: TextInputAction.search,
            // Dismiss the keyboard when the user taps outside the search pill.
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            collapsedLogoBuilder: (context) {
              // Mirror the active tab icon so the collapsed pill feels
              // contextual — house on Today, headphones on Audio, etc.
              const tabIcons = [
                CupertinoIcons.house_fill,
                CupertinoIcons.news_solid,
                CupertinoIcons.headphones,
                CupertinoIcons.rectangle_fill_on_rectangle_angled_fill,
              ];
              return Center(
                child: Icon(
                  tabIcons[_selectedTab],
                  color: Colors.white,
                  size: 26,
                ),
              );
            },
          ),
          tabs: [
            GlassBottomBarTab(
              label: 'Today',
              icon: const Icon(CupertinoIcons.house),
              activeIcon: const Icon(CupertinoIcons.house_fill),
            ),
            GlassBottomBarTab(
              label: 'News+',
              icon: const Icon(CupertinoIcons.news_solid),
              activeIcon: const Icon(CupertinoIcons.news_solid),
            ),
            GlassBottomBarTab(
              label: 'Audio',
              icon: const Icon(CupertinoIcons.headphones),
            ),
            GlassBottomBarTab(
              label: 'Following',
              icon: const Icon(
                  CupertinoIcons.rectangle_fill_on_rectangle_angled_fill),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTodayView({Key? key}) {
    return CustomScrollView(
      key: key,
      slivers: [
        SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).top + 8)),
        SliverToBoxAdapter(child: _buildNewsHeader()),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        SliverToBoxAdapter(
          child: _buildSectionHeader(
              'Top Stories', 'Chosen by the Apple News editors.'),
        ),
        SliverToBoxAdapter(child: _buildHeroArticleCard(_kTopStories[0])),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildCompactArticleCard(_kTopStories[index + 1]),
            childCount: _kTopStories.length - 1,
          ),
        ),
        SliverToBoxAdapter(
            child: _buildSectionHeader('Trending Stories', null)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildCompactArticleCard(_kMoreArticles[index]),
            childCount: _kMoreArticles.length,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
        ),
      ],
    );
  }

  Widget _buildNewsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.apple, color: Colors.white, size: 28),
                  SizedBox(width: 4),
                  Text(
                    'News',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Text(
                '6 April',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _kNewsRed,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Try News+ Free',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _CategoryChip(label: _kCategories[index]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kNewsRed,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeroArticleCard(_Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                article.imageAsset,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              color: _kCardBackground,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.isLive) _buildLiveBadge(),
                  if (article.isLive) const SizedBox(height: 8),
                  Text(
                    article.publication,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (article.moreCoverage) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: _kSeparator),
                    const SizedBox(height: 10),
                    Text(
                      'MORE COVERAGE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactArticleCard(_Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: _kCardBackground,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.isLive) ...[
                      _buildLiveBadge(),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      article.publication,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (article.moreCoverage) ...[
                      const SizedBox(height: 10),
                      Text(
                        'MORE COVERAGE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  article.imageAsset,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kLiveBadge,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Live',
        style: TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchView({Key? key}) {
    return CustomScrollView(
      key: key,
      slivers: [
        SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).top + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.apple, color: Colors.white, size: 22),
                    SizedBox(width: 4),
                    Text(
                      'News',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
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
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.paddingOf(context).bottom + 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _TopicCard(topic: _kTopics[index]),
              childCount: _kTopics.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final _TopicCategory topic;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: topic.color),
          // Image at partial opacity so the category color dominates —
          // matches Apple News where the card IS the color, not the photo.
          Opacity(
            opacity: 0.45,
            child: Image.asset(
              topic.imageAsset,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            right: 12,
            child: Text(
              topic.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
