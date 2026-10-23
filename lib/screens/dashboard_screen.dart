import 'package:flutter/material.dart';
import 'package:passbook/l10n/app_localizations.dart';
import 'package:passbook/model/data_parser.dart';
import '../model/passbook_model.dart';
import '../model/announcement_model.dart';
import 'announcements_screen.dart';
import 'milk_slip_screen.dart';
import 'passbook_screen.dart';
import 'combined_report_screen.dart';
import 'ledger_screen.dart';
import 'milk_sale_screen.dart';
import 'profile_screen.dart';
import '../service/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import '../widget/dynamic_text.dart';
import '../widget/company_logo.dart';

class _QuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class DashboardScreen extends StatefulWidget {
  final int socCode;
  final int memCode;
  final int langCode;
  final String dairyType;
  final dynamic userInfo;
  final ValueChanged<bool>? onReloadingChanged;

  const DashboardScreen({
    super.key,
    required this.socCode,
    required this.memCode,
    required this.langCode,
    required this.dairyType,
    required this.userInfo,
    this.onReloadingChanged,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isInitialLoading = true;
  String? _loadError;
  List<PassbookModel> _allEntries = [];
  List<PassbookModel> _filteredEntries = [];
  List<AnnouncementModel> _announcements = [];

  int _selectedFilterIndex = 0; // 0: 1-10, 1: 11-20, 2: 21-30/31
  bool _isFilterInitialized = false;
  bool _isReloading = false;

  Map<String, dynamic>? _cachedMorningStats;
  Map<String, dynamic>? _cachedEveningStats;
  Map<String, dynamic>? _cachedCowStats;
  Map<String, dynamic>? _cachedBuffaloStats;
  List<String>? _cachedInsights;
  double? _cachedYearlyLiters;
  double? _cachedYearlyEarnings;
  double? _cachedTotalLiters;
  double? _cachedTotalEarnings;
  double? _cachedAvgFat;
  double? _cachedAvgRate;

  void _clearCachedStats() {
    _cachedMorningStats = null;
    _cachedEveningStats = null;
    _cachedCowStats = null;
    _cachedBuffaloStats = null;
    _cachedInsights = null;
    _cachedYearlyLiters = null;
    _cachedYearlyEarnings = null;
    _cachedTotalLiters = null;
    _cachedTotalEarnings = null;
    _cachedAvgFat = null;
    _cachedAvgRate = null;
  }

  void _recomputeDerivedStats() {
    double totalLiters = 0.0;
    double totalEarnings = 0.0;
    double weightedFat = 0.0;

    double mLiters = 0.0;
    double mEarnings = 0.0;
    double mWeightedFat = 0.0;

    double eLiters = 0.0;
    double eEarnings = 0.0;
    double eWeightedFat = 0.0;

    double cLiters = 0.0;
    double cEarnings = 0.0;

    double bLiters = 0.0;
    double bEarnings = 0.0;

    for (final e in _filteredEntries) {
      final l = e.liters;
      final amt = e.amount;
      final fat = e.fat;
      totalLiters += l;
      totalEarnings += amt;
      weightedFat += (fat * l);

      if (e.me == 1) {
        mLiters += l;
        mEarnings += amt;
        mWeightedFat += (fat * l);
      } else if (e.me == 2) {
        eLiters += l;
        eEarnings += amt;
        eWeightedFat += (fat * l);
      }

      final cobf = e.cobf?.toUpperCase().trim();
      if (cobf == 'C') {
        cLiters += l;
        cEarnings += amt;
      } else if (cobf == 'B') {
        bLiters += l;
        bEarnings += amt;
      }
    }

    _cachedTotalLiters = totalLiters;
    _cachedTotalEarnings = totalEarnings;
    _cachedAvgFat = totalLiters > 0.0 ? (weightedFat / totalLiters) : 0.0;
    _cachedAvgRate = totalLiters > 0.0 ? (totalEarnings / totalLiters) : 0.0;

    _cachedMorningStats = {
      'liters': mLiters,
      'earnings': mEarnings,
      'avgFat': mLiters > 0.0 ? (mWeightedFat / mLiters) : 0.0,
      'avgRate': mLiters > 0.0 ? (mEarnings / mLiters) : 0.0,
    };

    _cachedEveningStats = {
      'liters': eLiters,
      'earnings': eEarnings,
      'avgFat': eLiters > 0.0 ? (eWeightedFat / eLiters) : 0.0,
      'avgRate': eLiters > 0.0 ? (eEarnings / eLiters) : 0.0,
    };

    _cachedCowStats = {
      'liters': cLiters,
      'earnings': cEarnings,
      'percentage': totalLiters > 0.0 ? (cLiters / totalLiters) * 100 : 0.0,
    };

    _cachedBuffaloStats = {
      'liters': bLiters,
      'earnings': bEarnings,
      'percentage': totalLiters > 0.0 ? (bLiters / totalLiters) * 100 : 0.0,
    };

    _cachedInsights = _generateSmartInsights();

    int maxYear = DateTime.now().year;
    if (_allEntries.isNotEmpty) {
      maxYear = _allEntries.first.trndate.year;
      for (final e in _allEntries) {
        if (e.trndate.year > maxYear) maxYear = e.trndate.year;
      }
    }
    double yLiters = 0.0;
    double yEarnings = 0.0;
    for (final e in _allEntries) {
      if (e.trndate.year == maxYear) {
        yLiters += e.liters;
        yEarnings += e.amount;
      }
    }
    _cachedYearlyLiters = yLiters;
    _cachedYearlyEarnings = yEarnings;
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      await _fetchData();
    } catch (e) {
      _loadError = e.toString();
    }
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (forceRefresh) {
      final refreshed = await ApiService().refreshAuthToken();
      if (!refreshed) {
        throw Exception('Failed to refresh login session');
      }
    }

    final results = await Future.wait([
      ApiService().fetchPassbook(
        widget.socCode,
        widget.memCode,
        forceRefresh: forceRefresh,
      ),
      ApiService().fetchAnnouncements(
        widget.socCode,
        widget.memCode,
        forceRefresh: forceRefresh,
      ),
    ]);

    final List<PassbookModel> entries = results[0] as List<PassbookModel>;
    final List<AnnouncementModel> announcements = results[1] as List<AnnouncementModel>;

    if (!mounted) return;

    setState(() {
      _allEntries = entries;
      _announcements = announcements;
      if (entries.isNotEmpty && !_isFilterInitialized) {
        final sorted = List<PassbookModel>.from(entries)
          ..sort((a, b) => a.trndate.compareTo(b.trndate));
        final maxDate = sorted.last.trndate;
        final day = maxDate.day;
        if (day <= 10) {
          _selectedFilterIndex = 0;
        } else if (day <= 20) {
          _selectedFilterIndex = 1;
        } else {
          _selectedFilterIndex = 2;
        }
        _isFilterInitialized = true;
      }
      _computeFilteredEntries();
    });
  }

  /// Pure computation â€” no setState. Call inside an existing setState block.
  void _computeFilteredEntries() {
    _clearCachedStats();
    if (_allEntries.isEmpty) {
      _filteredEntries = [];
      _recomputeDerivedStats();
      return;
    }
    final sorted = List<PassbookModel>.from(_allEntries)
      ..sort((a, b) => a.trndate.compareTo(b.trndate));
    final maxDate = sorted.last.trndate;
    _filteredEntries = sorted.where((e) {
      if (e.trndate.year != maxDate.year || e.trndate.month != maxDate.month) {
        return false;
      }
      final day = e.trndate.day;
      switch (_selectedFilterIndex) {
        case 0:
          return day >= 1 && day <= 10;
        case 1:
          return day >= 11 && day <= 20;
        case 2:
          return day >= 21 && day <= 31;
        default:
          return false;
      }
    }).toList();
    _recomputeDerivedStats();
  }

  Future<void> _handleRefresh() async {
    await _fetchData(forceRefresh: true);
  }

  /// Force-reloads all member datasets from the server, then refreshes the dashboard.
  Future<void> reloadAll() async {
    await ApiService().syncMemberData(
      socCode: widget.socCode,
      memCode: widget.memCode,
      accNo: widget.userInfo.accno as int,
      appString: widget.userInfo.appString as String,
      forceRefresh: true,
    );

    final results = await Future.wait([
      ApiService().fetchPassbook(
        widget.socCode,
        widget.memCode,
      ),
      ApiService().fetchAnnouncements(
        widget.socCode,
        widget.memCode,
        forceRefresh: true,
      ),
    ]);

    if (!mounted) return;

    setState(() {
      _allEntries = results[0] as List<PassbookModel>;
      _announcements = results[1] as List<AnnouncementModel>;
      _computeFilteredEntries();
    });
  }

  Future<void> handleReloadAll() async {
    if (_isReloading) return;

    _setReloading(true);
    try {
      await reloadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.refreshAllSuccess),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.refreshAllFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setReloading(false);
    }
  }

  void _setReloading(bool value) {
    if (!mounted) return;
    setState(() => _isReloading = value);
    widget.onReloadingChanged?.call(value);
  }

  Widget _withReloadOverlay(Widget child) {
    if (!_isReloading) return child;

    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.refreshAllLoading,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double get _totalLiters => _cachedTotalLiters ?? 0.0;
  double get _totalEarnings => _cachedTotalEarnings ?? 0.0;
  double get _avgFat => _cachedAvgFat ?? 0.0;
  double get _avgRate => _cachedAvgRate ?? 0.0;

  // Session stats
  Map<String, dynamic> _getSessionStats(int me) {
    final sessionEntries = _filteredEntries.where((e) => e.me == me);
    if (sessionEntries.isEmpty) {
      return {'liters': 0.0, 'earnings': 0.0, 'avgFat': 0.0, 'avgRate': 0.0};
    }
    final liters = sessionEntries.fold(0.0, (sum, e) => sum + e.liters);
    final earnings = sessionEntries.fold(0.0, (sum, e) => sum + e.amount);
    final avgFat = liters > 0.0
        ? sessionEntries.fold(0.0, (sum, e) => sum + (e.fat * e.liters)) /
              liters
        : 0.0;
    final avgRate = liters > 0.0 ? earnings / liters : 0.0;

    return {
      'liters': liters,
      'earnings': earnings,
      'avgFat': avgFat,
      'avgRate': avgRate,
    };
  }

  // Animal stats
  Map<String, dynamic> _getAnimalStats(String code) {
    final animalEntries = _filteredEntries.where(
      (e) => e.cobf?.toUpperCase().trim() == code,
    );
    if (animalEntries.isEmpty) {
      return {'liters': 0.0, 'earnings': 0.0, 'percentage': 0.0};
    }
    final liters = animalEntries.fold(0.0, (sum, e) => sum + e.liters);
    final earnings = animalEntries.fold(0.0, (sum, e) => sum + e.amount);
    final percentage = _totalLiters > 0 ? (liters / _totalLiters) * 100 : 0.0;

    return {'liters': liters, 'earnings': earnings, 'percentage': percentage};
  }

  // Generate dynamic smart insights
  List<String> _generateSmartInsights() {
    final List<String> insights = [];
    if (_filteredEntries.isEmpty) return insights;

    // 1. Peak delivery day
    final Map<String, double> dailyLiters = {};
    for (var e in _filteredEntries) {
      final key = formatLanguageAwareDate(e.trndate, widget.langCode);
      dailyLiters[key] = (dailyLiters[key] ?? 0.0) + e.liters;
    }
    if (dailyLiters.isNotEmpty) {
      final peak = dailyLiters.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add(
        "Your peak delivery day was ${peak.key} with ${peak.value.toStringAsFixed(1)} Liters of milk.",
      );
    }

    // 2. Cow vs Buffalo comparison
    final cowStats = _getAnimalStats('C');
    final buffStats = _getAnimalStats('B');
    if (cowStats['liters'] > 0 && buffStats['liters'] > 0) {
      final diff =
          (cowStats['percentage'] as double) -
          (buffStats['percentage'] as double);
      if (diff > 0) {
        insights.add(
          "You delivered more Cow milk (${cowStats['percentage'].toStringAsFixed(0)}%) than Buffalo milk (${buffStats['percentage'].toStringAsFixed(0)}%).",
        );
      } else {
        insights.add(
          "You delivered more Buffalo milk (${buffStats['percentage'].toStringAsFixed(0)}%) than Cow milk (${cowStats['percentage'].toStringAsFixed(0)}%).",
        );
      }

      // Fat comparison
      final cowEntries = _filteredEntries.where(
        (e) => e.cobf?.toUpperCase().trim() == 'C',
      );
      final buffEntries = _filteredEntries.where(
        (e) => e.cobf?.toUpperCase().trim() == 'B',
      );
      final cowFat =
          cowEntries.fold(0.0, (sum, e) => sum + e.fat) / cowEntries.length;
      final buffFat =
          buffEntries.fold(0.0, (sum, e) => sum + e.fat) / buffEntries.length;
      final fatDiff = (buffFat - cowFat).abs();
      insights.add(
        "Buffalo milk has on average ${fatDiff.toStringAsFixed(2)}% higher fat content than Cow milk.",
      );
    }

    // 3. Session comparison
    final morning = _getSessionStats(1);
    final evening = _getSessionStats(2);
    final mVol = morning['liters'] as double;
    final eVol = evening['liters'] as double;
    if (mVol > 0 && eVol > 0) {
      final total = mVol + eVol;
      final mPercent = (mVol / total) * 100;
      insights.add(
        "Morning sessions account for ${mPercent.toStringAsFixed(0)}% of your total milk volume.",
      );
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _withReloadOverlay(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Error: $_loadError",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }
    if (_allEntries.isEmpty) {
      return _withReloadOverlay(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noEntriesFound,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final morningStats = _cachedMorningStats!;
    final eveningStats = _cachedEveningStats!;
    final cowStats = _cachedCowStats!;
    final buffaloStats = _cachedBuffaloStats!;
    final insights = _cachedInsights ?? const <String>[];

    return _withReloadOverlay(
      RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAnnouncements(colorScheme),
                const SizedBox(height: 16),
                _buildHeaderCard(isDark, colorScheme),
                const SizedBox(height: 16),
                _buildQuickActions(context, colorScheme, l10n),
                const SizedBox(height: 20),
                _buildPeriodFilters(colorScheme),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildStatCardAt(index, isDark, colorScheme, l10n),
                childCount: 6,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (cowStats['liters'] > 0 || buffaloStats['liters'] > 0)
                  _buildAnimalComparison(
                    cowStats,
                    buffaloStats,
                    isDark,
                    colorScheme,
                    l10n,
                  ),
                if (cowStats['liters'] > 0 || buffaloStats['liters'] > 0)
                  const SizedBox(height: 20),
                _buildSessionComparison(
                  morningStats,
                  eveningStats,
                  isDark,
                  colorScheme,
                  l10n,
                ),
                const SizedBox(height: 20),
                if (insights.isNotEmpty)
                  _buildInsightsCard(insights, isDark, colorScheme),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final bool isMilkSaleSupported =
        widget.userInfo.appString.split(',').contains('5');
    final actions = [
      _QuickActionItem(
        icon: Icons.refresh,
        label: l10n.refreshAllData,
        color: const Color(0xFF4CAF50),
        onTap: handleReloadAll,
      ),
      _QuickActionItem(
        icon: Icons.receipt_long,
        label: l10n.milk_slips,
        color: const Color(0xFFFF9800),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MilkSlipScreen(
              socCode: widget.socCode,
              memCode: widget.memCode,
              langCode: widget.langCode,
              dairyType: widget.dairyType,
            ),
          ),
        ),
      ),
      _QuickActionItem(
        icon: Icons.local_drink,
        label: l10n.milk_passbook,
        color: const Color(0xFF2196F3),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassbookScreen(
              socCode: widget.socCode,
              memCode: widget.memCode,
              langCode: widget.langCode,
              dairyType: widget.dairyType,
            ),
          ),
        ),
      ),
      _QuickActionItem(
        icon: Icons.analytics_outlined,
        label: l10n.reports,
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CombinedReportScreen(
              socCode: widget.socCode,
              memCode: widget.memCode,
              langCode: widget.langCode,
              cobfType: widget.userInfo.cobfType,
              rptType: widget.userInfo.rptType,
            ),
          ),
        ),
      ),
      _QuickActionItem(
        icon: Icons.account_balance_wallet,
        label: l10n.ledger,
        color: const Color(0xFF795548),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LedgerScreen(
              socCode: widget.socCode,
              accNo: widget.userInfo.accno,
              langCode: widget.langCode,
            ),
          ),
        ),
      ),
      if (isMilkSaleSupported)
        _QuickActionItem(
          icon: Icons.local_drink_outlined,
          label: l10n.milk_sale,
          color: const Color(0xFF607D8B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MilkSalePage(
                socCode: widget.socCode,
                memCode: widget.memCode,
                langCode: widget.langCode,
              ),
            ),
          ),
        ),
      _QuickActionItem(
        icon: Icons.person_outline,
        label: l10n.myProfile,
        color: const Color(0xFF009688),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              userInfo: widget.userInfo,
              langCode: widget.langCode,
            ),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            "Quick Actions",
            style: AppTextStyles.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final item = actions[index];
              final isRefreshAction = index == 0;
              return GestureDetector(
                onTap: (_isReloading && isRefreshAction) ? null : item.onTap,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (_isReloading && isRefreshAction) ? 0.7 : 1.0,
                  child: Container(
                  width: 82,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color.withValues(alpha: 0.15),
                          border: Border.all(
                            color: item.color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: isRefreshAction && _isReloading
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: item.color,
                                ),
                              )
                            : Icon(
                                item.icon,
                                color: item.color,
                                size: 26,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
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
      ],
    );
  }

  Widget _buildAnnouncements(ColorScheme colorScheme) {
    final activeAnnouncements = _announcements.where((a) => a.isActive).toList();
    if (activeAnnouncements.isEmpty) return const SizedBox.shrink();

    final bool hasMore = activeAnnouncements.length > 2;
    final displayList = hasMore ? activeAnnouncements.take(2).toList() : activeAnnouncements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...displayList.map((announcement) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.2),
                    colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.campaign,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (announcement.societyMessageHead != null &&
                            announcement.societyMessageHead!.trim().isNotEmpty)
                          Text(
                            announcement.societyMessageHead!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        if (announcement.societyMessageTitle != null &&
                            announcement.societyMessageTitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            announcement.societyMessageTitle!,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (announcement.endDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Valid until: ${announcement.endDate!.day}/${announcement.endDate!.month}/${announcement.endDate!.year}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primary,
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
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnnouncementsScreen(
                        announcements: activeAnnouncements,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.arrow_forward, size: 18, color: colorScheme.primary),
                label: Text(
                  "Show More",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- BUILD WIDGETS ---

  Widget _buildHeaderCard(bool isDark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3C72), const Color(0xFF2A5298)]
              : [AppTheme.primaryBlue, AppTheme.darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: CompanyLogo(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DynamicText(
                  text: widget.userInfo?.memName ?? 'Member Statistics',
                  langCode: widget.langCode,
                  style: AppTextStyles.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: ${widget.memCode} | Society: ${widget.socCode}',
                  style: AppTextStyles.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilters(ColorScheme colorScheme) {
    final filters = ['1-10', '11-20', '21-30/31'];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilterIndex = index;
                  _computeFilteredEntries();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  filters[index],
                  style: AppTextStyles.poppins(
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatCardAt(
    int index,
    bool isDark,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    switch (index) {
      case 0:
        return _buildStatCard(
          title: l10n.dashboardTotalMilk,
          value: '${_totalLiters.toStringAsFixed(2)} ',
          icon: Icons.water_drop_rounded,
          colors: isDark
              ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
              : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        );
      case 1:
        return _buildStatCard(
          title: l10n.dashboardTotalAmount,
          value: ' ${_totalEarnings.toStringAsFixed(2)}',
          icon: Icons.payments_rounded,
          colors: isDark
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
        );
      case 2:
        return _buildStatCard(
          title: l10n.dashboardAverageFat,
          value: '${_avgFat.toStringAsFixed(1)} ',
          icon: Icons.opacity_rounded,
          colors: isDark
              ? [const Color(0xFFEF6C00), const Color(0xFFE65100)]
              : [const Color(0xFFFF9800), const Color(0xFFF57C00)],
        );
      case 3:
        return _buildStatCard(
          title: l10n.dashboardAvgRate,
          value: ' ${_avgRate.toStringAsFixed(2)}',
          icon: Icons.trending_up_rounded,
          colors: isDark
              ? [const Color(0xFF6A1B9A), const Color(0xFF4A148C)]
              : [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
        );
      case 4:
        return _buildStatCard(
          title: l10n.yearlyMilk,
          value: '${(_cachedYearlyLiters ?? 0.0).toStringAsFixed(2)} ',
          icon: Icons.calendar_today_rounded,
          colors: isDark
              ? [const Color(0xFF00838F), const Color(0xFF006064)]
              : [const Color(0xFF00BCD4), const Color(0xFF00ACC1)],
          forceKiranTitle: false,
          forceKiranValue: true,
        );
      default:
        return _buildStatCard(
          title: l10n.yearlyAmount,
          value: ' ${(_cachedYearlyEarnings ?? 0.0).toStringAsFixed(2)}',
          icon: Icons.analytics_rounded,
          colors: isDark
              ? [const Color(0xFFAD1457), const Color(0xFF880E4F)]
              : [const Color(0xFFE91E63), const Color(0xFFD81B60)],
          forceKiranTitle: false,
          forceKiranValue: true,
        );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    bool forceKiranTitle = false,
    bool forceKiranValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DynamicText(
                  text: title,
                  langCode: widget.langCode,
                  forceKiran: forceKiranTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          DynamicText(
            text: value,
            langCode: widget.langCode,
            forceKiran: forceKiranValue,
            style: AppTextStyles.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalComparison(
    Map<String, dynamic> cow,
    Map<String, dynamic> buffalo,
    bool isDark,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final cowLiters = cow['liters'] as double;
    final buffLiters = buffalo['liters'] as double;
    final total = cowLiters + buffLiters;
    final cowPercent = total > 0 ? (cowLiters / total) * 100 : 0.0;
    final buffPercent = total > 0 ? (buffLiters / total) * 100 : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cattle Type Comparison',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Cow breakdown
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.cow,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DynamicText(
                        text: '${cowLiters.toStringAsFixed(1)} L',
                        langCode: widget.langCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'â‚¹ ${cow['earnings'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical Divider
                Container(
                  width: 1,
                  height: 60,
                  color: colorScheme.outlineVariant,
                ),
                // Buffalo breakdown
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          color: AppTheme.warningOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.buffalo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DynamicText(
                        text: '${buffLiters.toStringAsFixed(1)} L',
                        langCode: widget.langCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'â‚¹ ${buffalo['earnings'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Double Progress Bar
            ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (cowLiters > 0)
                      Expanded(
                        flex: cowPercent.round(),
                        child: Container(color: AppTheme.primaryBlue),
                      ),
                    if (buffLiters > 0)
                      Expanded(
                        flex: buffPercent.round(),
                        child: Container(color: AppTheme.warningOrange),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (cowLiters > 0)
                  Text(
                    'Cow: ${cowPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (buffLiters > 0)
                  Text(
                    'Buffalo: ${buffPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionComparison(
    Map<String, dynamic> morning,
    Map<String, dynamic> evening,
    bool isDark,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Analysis (Morning vs. Evening)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Morning card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFFFF9C4).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3E3E3E)
                            : const Color(0xFFFFF59D),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              color: Colors.amber.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Morning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSessionStatRow(
                          'Liters:',
                          '${(morning['liters'] as double).toStringAsFixed(1)} L',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Earnings:',
                          'â‚¹ ${(morning['earnings'] as double).toStringAsFixed(0)}',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Avg FAT:',
                          '${(morning['avgFat'] as double).toStringAsFixed(2)} %',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Avg Rate:',
                          'â‚¹ ${(morning['avgRate'] as double).toStringAsFixed(1)}',
                          colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Evening card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE8EAF6).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3E3E3E)
                            : const Color(0xFFC5CAE9),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.nights_stay_rounded,
                              color: Colors.indigo.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Evening',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSessionStatRow(
                          'Liters:',
                          '${(evening['liters'] as double).toStringAsFixed(1)} L',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Earnings:',
                          'â‚¹ ${(evening['earnings'] as double).toStringAsFixed(0)}',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Avg FAT:',
                          '${(evening['avgFat'] as double).toStringAsFixed(2)} %',
                          colorScheme,
                        ),
                        const Divider(height: 12),
                        _buildSessionStatRow(
                          'Avg Rate:',
                          'â‚¹ ${(evening['avgRate'] as double).toStringAsFixed(1)}',
                          colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatRow(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        DynamicText(
          text: value,
          langCode: widget.langCode,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInsightsCard(
    List<String> insights,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Smart Activity Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(insights.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insights[index],
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

