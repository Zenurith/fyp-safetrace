import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../providers/user_provider.dart';

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final userProvider = context.read<UserProvider>();

      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Authentication failed - no user returned',
        );
      }
      await userProvider.loadUser(user.uid);
      if (userProvider.currentUser?.isAdmin != true) {
        await auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = 'Access denied. Admin privileges required.';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Authentication failed.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            // Wide: split panel layout
            return Row(
              children: [
                const SizedBox(
                  width: 340,
                  child: _BrandPanel(),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: _buildFormContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Narrow: centered card
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(36),
                  decoration: AppTheme.cardDecoration,
                  child: _buildFormContent(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sign in',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Access the SafeTrace admin dashboard.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 36),

          // Email
          const _FieldLabel('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: AppTheme.primaryDark,
            ),
            decoration: InputDecoration(
              hintText: 'admin@example.com',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryRed,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
          ),
          const SizedBox(height: 20),

          // Password
          const _FieldLabel('Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: AppTheme.primaryDark,
            ),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryRed,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) => (value == null || value.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.primaryRed.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 15, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Sign in button
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primaryRed.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Brand panel (wide layout only) ─────────────────────────────────────────

class _FeatureItem {
  final IconData icon;
  final String text;
  const _FeatureItem(this.icon, this.text);
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    _FeatureItem(Icons.people_outline, 'Community Safety Platform'),
    _FeatureItem(Icons.notifications_outlined, 'Real-time Incident Monitoring'),
    _FeatureItem(Icons.bar_chart, 'Moderation & Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryDark,
      padding: const EdgeInsets.all(44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 16),
          const Text(
            'SafeTrace',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin Console',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w300,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const Spacer(),
          for (final item in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.icon,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.text,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          Text(
            'Authorized personnel only.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.22),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryDark,
        letterSpacing: 0.2,
      ),
    );
  }
}
