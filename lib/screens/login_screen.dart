import 'package:flutter/material.dart';
import 'package:passbook/model/mem_info_model.dart';
import 'package:passbook/screens/main_screen.dart';
import 'package:passbook/model/saved_account.dart';
import 'package:passbook/service/account_session_service.dart';
import 'package:passbook/service/api_service.dart';
import 'package:passbook/service/firebaseApi.dart';
import 'package:passbook/service/language_services.dart';
import 'package:provider/provider.dart';
import 'package:passbook/theme/app_theme.dart';
import 'package:passbook/utils/error_mappers.dart';
import 'package:passbook/utils/user_facing_error.dart';

class LoginScreen extends StatefulWidget {
  final UserFacingError? initialMessage;
  final bool addAccountMode;
  final String? restoreAccountId;
  final String? fixedPhoneNumber;

  const LoginScreen({
    super.key,
    this.initialMessage,
    this.addAccountMode = false,
    this.restoreAccountId,
    this.fixedPhoneNumber,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dairyCodeController;
  late final TextEditingController _phoneController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _dairyCodeController = TextEditingController();

    // When adding another account, pre-fill and lock the user's phone number
    final phoneToUse = widget.fixedPhoneNumber ??
        (widget.addAccountMode ? ApiService().currentUser?.mobNo : null) ??
        '';
    _phoneController = TextEditingController(text: phoneToUse);

    _animationController.forward();

    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showUserMessage(context, widget.initialMessage!, preferDialog: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dairyCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<int?> _showAccountSelectionModal({
    required BuildContext context,
    required List<int> memberCodes,
    required MemInfoModel baseInfo,
  }) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          color: AppTheme.primaryBlue,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Account',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${baseInfo.socName ?? 'Dairy'} (${baseInfo.socCode})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${memberCodes.length} Accounts',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Multiple member accounts were found for this mobile number. Please choose which account you want to open:',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: memberCodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final code = memberCodes[index];
                      final isDefault = code == baseInfo.membCode;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(modalContext).pop(code);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2A2A2A)
                                  : (isDefault
                                      ? AppTheme.lightBlue.withValues(alpha: 0.5)
                                      : const Color(0xFFF8F9FA)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDefault
                                    ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                                    : (isDarkMode ? Colors.white12 : Colors.grey.shade300),
                                width: isDefault ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDefault
                                        ? AppTheme.primaryBlue
                                        : (isDarkMode ? Colors.white12 : Colors.grey.shade200),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$code',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDefault
                                            ? Colors.white
                                            : (isDarkMode ? Colors.white : AppTheme.textPrimary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Member #$code',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode ? Colors.white : AppTheme.textPrimary,
                                            ),
                                          ),
                                          if (isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.successGreen.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Primary',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.successGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Society Code: ${baseInfo.socCode}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.white60 : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: isDefault
                                      ? AppTheme.primaryBlue
                                      : (isDarkMode ? Colors.white38 : Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(modalContext).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dairyCode = _dairyCodeController.text.trim();
      final phoneNumber = _phoneController.text.trim();

      // Check member codes array and perform base login in parallel
      final memberCodesFuture = ApiService.fetchMemberCodes(
        dairyCode,
        phoneNumber,
      );
      final loginFuture = ApiService.login(
        dairyCode,
        phoneNumber,
        saveToSession: false,
      );

      final results = await Future.wait([
        memberCodesFuture,
        loginFuture,
      ]);

      if (!mounted) return;

      final List<int> memberCodes = results[0] as List<int>;
      final LoginResponse result = results[1] as LoginResponse;

      if (!result.success || result.data == null) {
        showUserMessage(context, mapLoginResponse(result), preferDialog: true);
        return;
      }

      final MemInfoModel baseUserInfo = result.data!;

      // Combine member codes list ensuring distinct, sorted values
      final Set<int> allCodes = {
        baseUserInfo.membCode,
        ...memberCodes,
      };
      final uniqueCodes = allCodes.toList()..sort();

      int selectedMembCode = baseUserInfo.membCode;

      // If more than 1 account exists, give the user the option to select
      if (uniqueCodes.length > 1) {
        setState(() {
          _isLoading = false;
        });

        final chosenCode = await _showAccountSelectionModal(
          context: context,
          memberCodes: uniqueCodes,
          baseInfo: baseUserInfo,
        );

        if (!mounted) return;

        if (chosenCode == null) {
          // User dismissed selection modal
          return;
        }

        selectedMembCode = chosenCode;
      }

      final MemInfoModel userInfo = baseUserInfo.copyWith(
        membCode: selectedMembCode,
        accno: selectedMembCode,
      );

      final languageService = Provider.of<LanguageService>(context, listen: false);

      if (widget.addAccountMode) {
        final accountService = AccountSessionService();
        final restoreId =
            widget.restoreAccountId ?? await accountService.getActiveAccountId();

        await accountService.saveAccount(
          userInfo,
          userInfo.authtoken ?? '',
          setActive: false,
        );

        // Also save all sibling accounts as inactive saved accounts
        if (uniqueCodes.length > 1) {
          for (final code in uniqueCodes) {
            if (code != userInfo.membCode) {
              final sibling = baseUserInfo.copyWith(
                membCode: code,
                accno: code,
              );
              await accountService.saveAccount(
                sibling,
                sibling.authtoken ?? '',
                setActive: false,
              );
            }
          }
        }

        if (restoreId != null && restoreId != SavedAccount.idFor(userInfo)) {
          final switched = await accountService.switchToAccount(restoreId);
          if (switched) {
            final session = await accountService.loadSession(restoreId);
            if (session != null) {
              await ApiService().activateSession(session.user, session.token);
              languageService.changeLocaleFromLangCode(session.user.langCode);
            }
          }
        } else {
          await ApiService().activateSession(
            userInfo,
            userInfo.authtoken ?? '',
          );
          languageService.changeLocaleFromLangCode(userInfo.langCode);
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      // Normal Login: Activate and save active account session
      final accountService = AccountSessionService();
      await accountService.saveAccount(
        userInfo,
        userInfo.authtoken ?? '',
        setActive: true,
      );
      await ApiService().activateSession(
        userInfo,
        userInfo.authtoken ?? '',
      );

      // Also register all other sibling accounts so user can switch between them
      if (uniqueCodes.length > 1) {
        for (final code in uniqueCodes) {
          if (code != userInfo.membCode) {
            final sibling = baseUserInfo.copyWith(
              membCode: code,
              accno: code,
            );
            await accountService.saveAccount(
              sibling,
              sibling.authtoken ?? '',
              setActive: false,
            );
          }
        }
      }

      languageService.changeLocaleFromLangCode(userInfo.langCode);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(
            userInfo: userInfo,
            initialNotice: loginSuccessMessage(),
            registerNotifications: () => CustomFirebaseApi().initNotifications(
              userInfo.authtoken ?? '',
              userInfo.socCode,
              userInfo.membCode,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Login: Unexpected error: $e');
      if (mounted) {
        showUserMessage(context, mapUnexpectedError(e), preferDialog: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine if we should use compact layout
            final isCompactHeight = constraints.maxHeight < 600;
            
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.06,
                  vertical: isCompactHeight ? 16 : 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Spacing at top
                        if (!keyboardVisible && !isCompactHeight)
                          const SizedBox(height: 20),
                        
                        // Logo/Header Section
                        _buildHeader(isDarkMode, isCompactHeight),
                        
                        SizedBox(height: isCompactHeight ? 24 : 32),
                        
                        // Welcome Text
                        _buildWelcomeText(isDarkMode, isCompactHeight),
                        
                        SizedBox(height: isCompactHeight ? 24 : 32),
                        
                        // Login Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _dairyCodeController,
                                label: 'Dairy Code',
                                hint: 'Enter your dairy code',
                                icon: Icons.business_rounded,
                                keyboardType: TextInputType.text,
                                maxLength: 10,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter dairy code';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: isCompactHeight ? 16 : 20),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                hint: 'Enter your phone number',
                                icon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                readOnly: widget.addAccountMode,
                                suffixIcon: widget.addAccountMode
                                    ? Padding(
                                        padding: const EdgeInsets.only(right: 14),
                                        child: Tooltip(
                                          message:
                                              'Phone number is locked to your account',
                                          child: Icon(
                                            Icons.lock_rounded,
                                            size: 20,
                                            color: isDarkMode
                                                ? Colors.white38
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                      )
                                    : null,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  if (value.length != 10) {
                                    return 'Phone number must be 10 digits';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: isCompactHeight ? 24 : 32),
                        
                        // Login Button
                        _buildLoginButton(),
                        
                        SizedBox(height: isCompactHeight ? 16 : 24),
                        
                        // Help Text
                        _buildHelpText(isDarkMode),
                        
                        // Spacing at bottom
                        if (!keyboardVisible && !isCompactHeight)
                          const SizedBox(height: 20),
                        
                        // Bottom padding for small screens
                        if (isCompactHeight || keyboardVisible)
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, bool isCompact) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: isCompact ? 60 : 80,
          width: isCompact ? 60 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.lock_rounded,
            size: isCompact ? 30 : 40,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText(bool isDarkMode, bool isCompact) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          widget.addAccountMode ? 'Add Another Account' : 'Welcome Back',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: isCompact ? 24 : 28,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          widget.addAccountMode
              ? 'Enter new Dairy Code for your registered mobile number'
              : 'Sign in to continue to your account',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: isCompact ? 14 : 15,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHelpText(bool isDarkMode) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Need help? Contact support',
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          readOnly: readOnly,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: readOnly
                ? (isDarkMode ? Colors.white70 : Colors.black87)
                : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.white30 : Colors.black38,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            filled: true,
            fillColor: readOnly
                ? (isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100)
                : theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.dividerColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.dividerColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: readOnly ? theme.dividerColor : theme.colorScheme.primary,
                width: readOnly ? 1 : 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final theme = Theme.of(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [theme.disabledColor, theme.disabledColor]
              : [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _performLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.addAccountMode ? 'Add Account' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }
}


