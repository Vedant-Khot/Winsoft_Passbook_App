import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:passbook/l10n/app_localizations.dart';
import '../model/mem_info_model.dart';
import '../model/saved_account.dart';
import '../service/account_session_service.dart';
import '../service/api_service.dart';
import '../service/firebaseApi.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../widget/dynamic_text.dart';
import '../theme/app_theme.dart';
import '../widget/company_logo.dart';
import 'package:provider/provider.dart';
import '../service/language_services.dart';
import '../theme/app_text_styles.dart';

class ProfileScreen extends StatefulWidget {
  final MemInfoModel userInfo;
  final int langCode;

  const ProfileScreen({
    super.key,
    required this.userInfo,
    required this.langCode,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isReloading = false;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await AccountSessionService().getSavedAccounts();
    if (mounted) {
      setState(() => _savedAccounts = accounts);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Scaffold(
      body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(l10n),
              SliverToBoxAdapter(child: _buildRefreshCard(l10n)),
              SliverToBoxAdapter(child: _buildAccountsCard(l10n)),
              _buildInfoCardsList(l10n),
            ],
          ),
        ),
        if (_isReloading)
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

  Future<void> _handleRefreshAll() async {
    if (_isReloading) return;

    setState(() => _isReloading = true);
    try {
      await ApiService().syncMemberData(
        socCode: widget.userInfo.socCode,
        memCode: widget.userInfo.membCode,
        accNo: widget.userInfo.accno,
        appString: widget.userInfo.appString,
        forceRefresh: true,
      );
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
            content: Text(
              '${AppLocalizations.of(context)!.refreshAllFailed}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  Future<void> _addAccount() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          addAccountMode: true,
          restoreAccountId: SavedAccount.idFor(widget.userInfo),
          fixedPhoneNumber: widget.userInfo.mobNo,
        ),
      ),
    );

    await _loadSavedAccounts();

    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.accountAdded),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _switchAccount(SavedAccount account) async {
    if (account.id == SavedAccount.idFor(widget.userInfo)) return;

    setState(() => _isReloading = true);
    try {
      final accountService = AccountSessionService();
      final switched = await accountService.switchToAccount(account.id);
      if (!switched) {
        throw Exception('Saved session not found');
      }

      final session = await accountService.loadSession(account.id);
      if (session == null) {
        throw Exception('Saved session not found');
      }

      await ApiService().activateSession(session.user, session.token);

      if (!mounted) return;
      final languageService = Provider.of<LanguageService>(context, listen: false);
      languageService.changeLocaleFromLangCode(session.user.langCode);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainScreen(
            userInfo: session.user,
            registerNotifications: () => CustomFirebaseApi().initNotifications(
              session.token,
              session.user.socCode,
              session.user.membCode,
            ),
          ),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.switchAccount}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAccount),
        content: Text(l10n.removeAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeAccount),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final isActive = account.id == SavedAccount.idFor(widget.userInfo);
    await AccountSessionService().removeAccount(account.id);

    if (!mounted) return;

    if (isActive) {
      final remaining = await AccountSessionService().getSavedAccounts();
      if (remaining.isEmpty) {
        await ApiService().clearActiveSession(clearSyncMetadata: true);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }

      await _switchAccount(remaining.first);
      return;
    }

    await _loadSavedAccounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.accountRemoved)),
    );
  }

  Future<void> _logoutAllAccounts() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildAccountsCard(AppLocalizations l10n) {
    final activeId = SavedAccount.idFor(widget.userInfo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.switch_account, color: AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  Text(
                    l10n.savedAccounts,
                    style: AppTextStyles.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._savedAccounts.map((account) {
                final isActive = account.id == activeId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.person,
                      color: isActive ? AppTheme.primaryBlue : Colors.grey,
                    ),
                  ),
                  title: DynamicText(
                    text: account.memName ?? 'Member ${account.membCode}',
                    langCode: account.langCode,
                    style: AppTextStyles.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${account.socName ?? 'Society'} • Member #${account.membCode} • ${account.mobNo ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.activeAccount,
                            style: AppTextStyles.poppins(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!isActive)
                        IconButton(
                          tooltip: l10n.switchAccount,
                          onPressed: _isReloading
                              ? null
                              : () => _switchAccount(account),
                          icon: const Icon(Icons.swap_horiz),
                        ),
                      IconButton(
                        tooltip: l10n.removeAccount,
                        onPressed: _isReloading
                            ? null
                            : () => _removeAccount(account),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: isActive || _isReloading
                      ? null
                      : () => _switchAccount(account),
                );
              }),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: Color(0xFF4CAF50)),
                ),
                title: Text(
                  l10n.addAccount,
                  style: AppTextStyles.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.addAccountSubtitle),
                onTap: _isReloading ? null : _addAccount,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: Text(
                  l10n.logoutAllAccounts,
                  style: AppTextStyles.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.logoutAllAccountsSubtitle),
                onTap: _isReloading ? null : _logoutAllAccounts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshCard(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _isReloading ? null : _handleRefreshAll,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isReloading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: Color(0xFF4CAF50),
                          size: 24,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.refreshAllData,
                        style: AppTextStyles.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.refreshAllDataSubtitle,
                        style: AppTextStyles.poppins(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(AppLocalizations l10n) {
    const Color primaryColor = AppTheme.primaryBlue;
    return SliverAppBar(
      expandedHeight: 260.0,
      pinned: true,
      elevation: 0,
      title: Text(
        l10n.profile_title,
        style: AppTextStyles.poppins(
          color: Colors.white,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          alignment: Alignment.center,
          child: const CompanyLogo(size: 32),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(color: primaryColor),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: const CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 42, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DynamicText(
                    text: widget.userInfo.memName ?? 'Member Name',
                    langCode: widget.langCode,
                    style: AppTextStyles.poppins(
                      color: Colors.white,
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.poppins(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.0,
                      ),
                      children: [
                        TextSpan(text: '${l10n.profile_memberId}: '),
                        TextSpan(
                          text: widget.userInfo.membCode.toString(),
                          style: AppTextStyles.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCardsList(AppLocalizations l10n) {
    final user = widget.userInfo;

    final List<Map<String, dynamic>> cardData = [
      {
        'title': l10n.profile_personalInfo,
        'icon': Icons.person_pin,
        'color': AppTheme.primaryBlue,
        'items': [
          {
            'icon': Icons.tag,
            'label': l10n.profile_memberCode,
            'value': user.membCode.toString(),
          },
          {
            'icon': Icons.phone_android,
            'label': l10n.profile_mobileNumber,
            'value': user.mobNo ?? l10n.profile_notProvided,
          },
        ],
      },
      {
        'title': l10n.profile_societyInfo,
        'icon': Icons.business_center,
        'color': const Color(0xFF43A047),
        'items': [
          {
            'icon': Icons.corporate_fare,
            'label': l10n.profile_societyName,
            'value': user.socName ?? l10n.profile_notProvided,
          },
          {
            'icon': Icons.pin_drop,
            'label': l10n.profile_societyCode,
            'value': user.socCode.toString(),
          },
        ],
      },
      // {
      //   'title': l10n.profile_accountDetails,
      //   'icon': Icons.security,
      //   'color': const Color(0xFF757575),
      //   'items': [
      //     {
      //       'icon': Icons.timer_off_outlined,
      //       'label': l10n.profile_tokenExpires,
      //       'value': DateFormat('dd MMM yyyy, hh:mm a').format(user.expireDate),
      //     },
      //     {
      //       'icon': Icons.receipt,
      //       'label': l10n.profile_billType,
      //       'value': user.billtype.toString(),
      //     },
      //   ],
      // },
    ];

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Staggered animation for each card
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            0.2 * index,
            0.6 + (0.2 * index),
            curve: Curves.easeOut,
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                index == cardData.length - 1 ? 24 : 0,
              ),
              child: _buildInfoCard(
                title: cardData[index]['title'],
                icon: cardData[index]['icon'],
                color: cardData[index]['color'],
                children: (cardData[index]['items'] as List).map((item) {
                  return _buildInfoRow(
                    icon: item['icon'],
                    label: item['label'],
                    value: item['value'],
                    valueLangCode: (item['label'] == l10n.profile_societyName)
                        ? widget.langCode
                        : 1,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      }, childCount: cardData.length),
    );
  }

  /// Builds a single, beautifully styled info card.
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  /// Builds a single, styled row of information within a card.
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    int valueLangCode = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.45), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 4),
                DynamicText(
                  text: value,
                  langCode: valueLangCode,
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

