import 'package:flutter/material.dart';
import 'package:passbook/l10n/app_localizations.dart';
import 'package:passbook/screens/milk_sale_screen.dart';
import 'package:passbook/widget/dynamic_text.dart';
import 'package:passbook/widget/company_logo.dart';
import 'package:provider/provider.dart';
import 'package:passbook/screens/combined_report_screen.dart';
import 'package:passbook/screens/ledger_screen.dart';
import 'package:passbook/screens/profile_screen.dart';
import 'package:passbook/model/fcm_init_result.dart';
import 'package:passbook/utils/error_mappers.dart';
import 'package:passbook/utils/user_facing_error.dart';
import '../model/mem_info_model.dart';
import 'passbook_screen.dart';
import 'package:passbook/screens/milk_slip_screen.dart';
import '../service/theme_service.dart';
import '../theme/app_theme.dart';
import 'package:passbook/screens/dashboard_screen.dart';

void _openScreenAfterDrawer(BuildContext context, Widget screen) {
  Navigator.of(context).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  });
}

class MainScreen extends StatefulWidget {
  final MemInfoModel userInfo;
  final Future<FcmInitResult> Function()? registerNotifications;
  final UserFacingError? initialNotice;

  const MainScreen({
    super.key,
    required this.userInfo,
    this.registerNotifications,
    this.initialNotice,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  late final Widget _dashboard;
  late AnimationController _drawerAnimationController;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    _dashboard = DashboardScreen(
      key: _dashboardKey,
      socCode: widget.userInfo.socCode,
      memCode: widget.userInfo.membCode,
      langCode: widget.userInfo.langCode,
      dairyType: widget.userInfo.dairyType.toString(),
      userInfo: widget.userInfo,
      onReloadingChanged: (loading) {
        if (mounted) {
          setState(() => _isReloading = loading);
        }
      },
    );

    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _runPostLoginSetup());
  }

  Future<void> _handleReload() async {
    await _dashboardKey.currentState?.handleReloadAll();
  }

  Future<void> _runPostLoginSetup() async {
    if (widget.initialNotice != null && mounted) {
      showUserMessage(context, widget.initialNotice!);
    }

    final register = widget.registerNotifications;

    if (register == null) return;

    try {
      final result = await register();
      if (!mounted) return;

      if (!result.isFullySuccessful && result.primaryWarning != null) {
        showUserMessage(context, result.primaryWarning!);
      }
    } catch (e) {
      if (mounted) {
        showUserMessage(context, mapFcmError(e));
      }
    }
  }

  @override
  void dispose() {
    _drawerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Dashboard';
    const icon = Icons.dashboard_rounded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildEnhancedAppBar(title, icon),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark
                  ? colorScheme.surface
                  : AppTheme.lightBlue.withValues(alpha: 0.3),
              scaffoldBg,
            ],
          ),
        ),
        child: RepaintBoundary(child: _dashboard),
      ),
      drawer: _AppDrawer(userInfo: widget.userInfo),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar(String title, IconData icon) {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
            _drawerAnimationController.forward();
          },
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Reload all data',
          onPressed: _isReloading ? null : _handleReload,
          icon: _isReloading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, size: 20),
                ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.center,
          child: const CompanyLogo(size: 32),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, size: 20),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userInfo: widget.userInfo,
                    langCode: widget.userInfo.langCode,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final MemInfoModel userInfo;
  const _AppDrawer({required this.userInfo});

  bool get _isMilkSaleSupported =>
      userInfo.appString.split(',').contains('5');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: RepaintBoundary(
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDrawerHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.dashboard_rounded,
                      title: l10n.dashboard,
                      subtitle: l10n.dashboardSubtitle,
                      isSelected: true,
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      color: AppTheme.primaryBlue,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.receipt_long,
                      title: l10n.milk_slips,
                      subtitle: l10n.milkSlipsSubtitle,
                      isSelected: false,
                      onTap: () {
                        _openScreenAfterDrawer(
                          context,
                          MilkSlipScreen(
                            socCode: userInfo.socCode,
                            memCode: userInfo.membCode,
                            langCode: userInfo.langCode,
                            dairyType: userInfo.dairyType.toString(),
                          ),
                        );
                      },
                      color: const Color(0xFFFF9800),
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.local_drink,
                      title: l10n.milk_passbook,
                      subtitle: l10n.milkPassbookSubtitle,
                      onTap: () {
                        _openScreenAfterDrawer(
                          context,
                          PassbookScreen(
                            socCode: userInfo.socCode,
                            memCode: userInfo.membCode,
                            langCode: userInfo.langCode,
                            dairyType: userInfo.dairyType.toString(),
                          ),
                        );
                      },
                      color: const Color(0xFF2196F3),
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.analytics_outlined,
                      title: l10n.reports,
                      subtitle: l10n.reportsSubtitle,
                      onTap: () {
                        _openScreenAfterDrawer(
                          context,
                          CombinedReportScreen(
                            socCode: userInfo.socCode,
                            memCode: userInfo.membCode,
                            langCode: userInfo.langCode,
                            cobfType: userInfo.cobfType,
                            rptType: userInfo.rptType,
                          ),
                        );
                      },
                      color: const Color(0xFF9C27B0),
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.account_balance_wallet,
                      title: l10n.ledger,
                      subtitle: l10n.ledgerSubtitle,
                      onTap: () {
                        _openScreenAfterDrawer(
                          context,
                          LedgerScreen(
                            socCode: userInfo.socCode,
                            accNo: userInfo.accno,
                            langCode: userInfo.langCode,
                          ),
                        );
                      },
                      color: const Color(0xFF795548),
                    ),
                    _isMilkSaleSupported
                        ? _buildDrawerItem(
                            context: context,
                            icon: Icons.local_drink_outlined,
                            title: l10n.milk_sale,
                            subtitle: l10n.milk_sale_details,
                            onTap: () {
                              _openScreenAfterDrawer(
                                context,
                                MilkSalePage(
                                  socCode: userInfo.socCode,
                                  memCode: userInfo.membCode,
                                  langCode: userInfo.langCode,
                                ),
                              );
                            },
                            color: const Color(0xFF607D8B),
                          )
                        : const SizedBox.shrink(),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline,
                      title: l10n.myProfile,
                      subtitle: l10n.myProfileSubtitle,
                      onTap: () {
                        _openScreenAfterDrawer(
                          context,
                          ProfileScreen(
                            userInfo: userInfo,
                            langCode: userInfo.langCode,
                          ),
                        );
                      },
                      color: const Color(0xFF607D8B),
                    ),
                    Consumer<ThemeService>(
                      builder: (context, themeService, _) {
                        final isDarkTheme = themeService.isDark;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isDarkTheme
                                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.6)
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDarkTheme
                                    ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                                    : Colors.orange.shade200,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, anim) =>
                                    RotationTransition(
                                      turns: anim,
                                      child: FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                    ),
                                child: Icon(
                                  isDarkTheme
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                                  key: ValueKey(isDarkTheme),
                                  color: isDarkTheme
                                      ? AppTheme.primaryBlue
                                      : Colors.orange.shade700,
                                  size: 26,
                                ),
                              ),
                              title: Text(
                                isDarkTheme ? l10n.darkMode : l10n.lightMode,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDarkTheme
                                      ? Colors.white
                                      : Colors.orange.shade900,
                                ),
                              ),
                              subtitle: Text(
                                isDarkTheme ? l10n.switchToLight : l10n.switchToDark,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkTheme
                                      ? Colors.white60
                                      : Colors.orange.shade700,
                                ),
                              ),
                              trailing: Switch(
                                value: isDarkTheme,
                                onChanged: (_) => themeService.toggleTheme(),
                                activeColor: AppTheme.primaryBlue,
                                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                                inactiveThumbColor: Colors.orange.shade400,
                                inactiveTrackColor: Colors.orange.shade100,
                              ),
                              onTap: () => themeService.toggleTheme(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: const BoxDecoration(color: AppTheme.primaryBlue),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DynamicText(
                  text: userInfo.memName ?? 'Member Name',
                  langCode: userInfo.langCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.business,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${userInfo.membCode}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DynamicText(
                  text: userInfo.socName ?? 'Dairy Cooperative',
                  langCode: userInfo.langCode,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    bool isSelected = false,
    bool showArrow = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? color.withValues(alpha: 0.15) : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
            color: isSelected ? color : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? color.withValues(alpha: 0.7)
                : colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        trailing: showArrow
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isSelected
                    ? color
                    : colorScheme.onSurface.withValues(alpha: 0.35),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
