// // lib/screens/login_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../components/custom_snackbar.dart';
// import '../providers/auth_provider.dart';
// import 'dashboard.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen>
//     with SingleTickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _obscurePassword = true;
//
//   late AnimationController _animCtrl;
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideAnim;
//
//   // ── Design tokens ──────────────────────────────────────────────────────────
//   static const _bg       = Color(0xFFF0F4FF);
//   static const _card     = Colors.white;
//   static const _primary  = Color(0xFF2563EB);
//   static const _textDark = Color(0xFF111827);
//   static const _textMid  = Color(0xFF6B7280);
//   static const _border   = Color(0xFFE5E7EB);
//   static const _inputBg  = Color(0xFFF9FAFB);
//   static const _error    = Color(0xFFEF4444);
//
//   @override
//   void initState() {
//     super.initState();
//     _animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _fadeAnim =
//         CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
//     _slideAnim = Tween<Offset>(
//       begin: const Offset(0, 0.08),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
//     _animCtrl.forward();
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     _animCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _login() async {
//     if (_formKey.currentState!.validate()) {
//       final auth = Provider.of<AuthProvider>(context, listen: false);
//       final result = await auth.login(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//       );
//       if (mounted) {
//         if (result['success']) {
//           CustomSnackbar.showSuccess(context, 'Login successful!');
//           _emailController.clear();
//           _passwordController.clear();
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (_) => const InventoryDashboardScreen()),
//           );
//         } else {
//           CustomSnackbar.showError(context, result['message']);
//         }
//       }
//     }
//   }
//
//   // ── Input decoration factory ───────────────────────────────────────────────
//   InputDecoration _inputDeco({
//     required String hint,
//     required IconData icon,
//     Widget? suffix,
//   }) {
//     return InputDecoration(
//       hintText: hint,
//       hintStyle:
//       TextStyle(color: _textMid.withOpacity(0.55), fontSize: 14),
//       prefixIcon: Padding(
//         padding: const EdgeInsets.only(left: 14, right: 10),
//         child: Icon(icon, size: 20, color: _textMid),
//       ),
//       prefixIconConstraints:
//       const BoxConstraints(minWidth: 48, minHeight: 48),
//       suffixIcon: suffix,
//       filled: true,
//       fillColor: _inputBg,
//       contentPadding:
//       const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: _border),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: _border),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: _primary, width: 1.8),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: _error),
//       ),
//       focusedErrorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: _error, width: 1.8),
//       ),
//       errorStyle: const TextStyle(fontSize: 12, color: _error),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _bg,
//       body: Stack(
//         children: [
//           // ── Soft background blobs ──────────────────────────────────────────
//           Positioned(
//             top: -130,
//             left: -90,
//             child: _Blob(size: 340, color: _primary.withOpacity(0.09)),
//           ),
//           Positioned(
//             bottom: -110,
//             right: -70,
//             child: _Blob(
//                 size: 300,
//                 color: const Color(0xFF60A5FA).withOpacity(0.10)),
//           ),
//           Positioned(
//             top: 200,
//             right: -50,
//             child: _Blob(size: 170, color: _primary.withOpacity(0.05)),
//           ),
//
//           // ── Scrollable content ─────────────────────────────────────────────
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 24, vertical: 40),
//                 child: FadeTransition(
//                   opacity: _fadeAnim,
//                   child: SlideTransition(
//                     position: _slideAnim,
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         // ── Logo ──────────────────────────────────────────
//                         Container(
//                           width: 200,
//                           height: 200,
//                           decoration: BoxDecoration(
//                             color: _card,
//                             borderRadius: BorderRadius.circular(28),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: _primary.withOpacity(0.20),
//                                 blurRadius: 36,
//                                 offset: const Offset(0, 12),
//                               ),
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.04),
//                                 blurRadius: 6,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           padding: const EdgeInsets.all(18),
//                           child: Image.asset(
//                             'asset/images/logo.png',
//                             fit: BoxFit.contain,
//                           ),
//                         ),
//
//                         const SizedBox(height: 30),
//
//                         // ── Headline ──────────────────────────────────────
//                         const Text(
//                           'Welcome Back',
//                           style: TextStyle(
//                             fontSize: 30,
//                             fontWeight: FontWeight.w800,
//                             color: _textDark,
//                             letterSpacing: -0.7,
//                             height: 1.1,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'Sign in to your account to continue',
//                           style: TextStyle(
//                             fontSize: 15,
//                             color: _textMid,
//                             height: 1.5,
//                           ),
//                         ),
//
//                         const SizedBox(height: 36),
//
//                         // ── Form card ─────────────────────────────────────
//                         Container(
//                           decoration: BoxDecoration(
//                             color: _card,
//                             borderRadius: BorderRadius.circular(24),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.07),
//                                 blurRadius: 28,
//                                 offset: const Offset(0, 8),
//                               ),
//                             ],
//                           ),
//                           padding: const EdgeInsets.all(28),
//                           child: Form(
//                             key: _formKey,
//                             child: Column(
//                               crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                               children: [
//                                 // ── Email ──────────────────────────────
//                                 const _FieldLabel(text: 'Email Address'),
//                                 const SizedBox(height: 8),
//                                 TextFormField(
//                                   controller: _emailController,
//                                   keyboardType:
//                                   TextInputType.emailAddress,
//                                   style: const TextStyle(
//                                       fontSize: 15, color: _textDark),
//                                   decoration: _inputDeco(
//                                     hint: 'you@example.com',
//                                     icon: Icons.email_outlined,
//                                   ),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Please enter your email';
//                                     }
//                                     if (!RegExp(
//                                         r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
//                                         .hasMatch(v)) {
//                                       return 'Please enter a valid email';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//
//                                 const SizedBox(height: 22),
//
//                                 // ── Password ───────────────────────────
//                                 Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     const _FieldLabel(text: 'Password'),
//
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 TextFormField(
//                                   controller: _passwordController,
//                                   obscureText: _obscurePassword,
//                                   style: const TextStyle(
//                                       fontSize: 15, color: _textDark),
//                                   decoration: _inputDeco(
//                                     hint: '••••••••',
//                                     icon: Icons.lock_outline_rounded,
//                                     suffix: GestureDetector(
//                                       onTap: () => setState(() =>
//                                       _obscurePassword =
//                                       !_obscurePassword),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                             right: 14),
//                                         child: Icon(
//                                           _obscurePassword
//                                               ? Icons
//                                               .visibility_off_outlined
//                                               : Icons
//                                               .visibility_outlined,
//                                           size: 20,
//                                           color: _textMid,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Please enter your password';
//                                     }
//                                     if (v.length < 6) {
//                                       return 'Password must be at least 6 characters';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//
//                                 const SizedBox(height: 32),
//
//                                 // ── Sign In button ─────────────────────
//                                 Consumer<AuthProvider>(
//                                   builder: (context, auth, _) {
//                                     return SizedBox(
//                                       width: double.infinity,
//                                       height: 52,
//                                       child: ElevatedButton(
//                                         onPressed: auth.isLoading
//                                             ? null
//                                             : _login,
//                                         style:
//                                         ElevatedButton.styleFrom(
//                                           backgroundColor: _primary,
//                                           foregroundColor: Colors.white,
//                                           disabledBackgroundColor:
//                                           _primary.withOpacity(0.55),
//                                           elevation: 0,
//                                           shadowColor: Colors.transparent,
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                             BorderRadius.circular(
//                                                 14),
//                                           ),
//                                         ),
//                                         child: auth.isLoading
//                                             ? const SizedBox(
//                                           width: 22,
//                                           height: 22,
//                                           child:
//                                           CircularProgressIndicator(
//                                             strokeWidth: 2.5,
//                                             color: Colors.white,
//                                           ),
//                                         )
//                                             : const Row(
//                                           mainAxisAlignment:
//                                           MainAxisAlignment
//                                               .center,
//                                           children: [
//                                             Text(
//                                               'Sign In',
//                                               style: TextStyle(
//                                                 fontSize: 16,
//                                                 fontWeight:
//                                                 FontWeight.w700,
//                                                 letterSpacing: 0.3,
//                                               ),
//                                             ),
//                                             SizedBox(width: 8),
//                                             Icon(
//                                               Icons
//                                                   .arrow_forward_rounded,
//                                               size: 18,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(height: 32),
//
//                         // ── Footer ────────────────────────────────────────
//                         Text(
//                           '© ${DateTime.now().year} All rights reserved.',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: _textMid.withOpacity(0.65),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Tiny helpers ────────────────────────────────────────────────────────────
//
// class _FieldLabel extends StatelessWidget {
//   final String text;
//   const _FieldLabel({required this.text});
//
//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       text,
//       style: const TextStyle(
//         fontSize: 13,
//         fontWeight: FontWeight.w600,
//         color: Color(0xFF374151),
//         letterSpacing: 0.1,
//       ),
//     );
//   }
// }
//
// class _Blob extends StatelessWidget {
//   final double size;
//   final Color color;
//   const _Blob({required this.size, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(shape: BoxShape.circle, color: color),
//     );
//   }
// }

// lib/screens/login_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_snackbar.dart';
import '../providers/auth_provider.dart';
import '../screens/dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateSlow;

  // ── Design tokens — pulled from Tech Soft logo ─────────────────────────────
  static const _bg         = Color(0xFF0A0E1A);   // deep navy-black
  static const _bgCard     = Color(0xFF111827);   // slightly lighter card
  static const _bgField    = Color(0xFF1A2235);   // input bg
  static const _teal       = Color(0xFF00D4C8);   // logo teal
  static const _cyan       = Color(0xFF38BDF8);   // logo cyan highlight
  static const _green      = Color(0xFF10D982);   // logo green accent
  static const _border     = Color(0xFF1E2D45);   // subtle border
  static const _borderFocus = Color(0xFF00D4C8);  // teal focus ring
  static const _textLight  = Color(0xFFF1F5F9);
  static const _textMid    = Color(0xFF94A3B8);
  static const _error      = Color(0xFFFF5C7A);

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _rotateSlow = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat(),
    );

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final result = await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        if (result['success']) {
          CustomSnackbar.showSuccess(context, 'Login successful!');
          _emailController.clear();
          _passwordController.clear();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const InventoryDashboardScreen()),
          );
        } else {
          CustomSnackbar.showError(context, result['message']);
        }
      }
    }
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textMid, fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: _textMid.withOpacity(0.4), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: _teal.withOpacity(0.8)),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bgField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderFocus, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error, width: 1.8),
      ),
      errorStyle: const TextStyle(fontSize: 11.5, color: _error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Animated background grid lines ─────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // ── Glowing orbs ───────────────────────────────────────────────────
          Positioned(
            top: -160,
            left: -100,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: _GlowOrb(
                size: 380,
                color: _teal.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: _GlowOrb(
                size: 420,
                color: _cyan.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 260,
            right: -60,
            child: _GlowOrb(size: 180, color: _green.withOpacity(0.04)),
          ),

          // ── Main content ───────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 36),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo with glow ring ──────────────────────────
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // outer glow ring
                            ScaleTransition(
                              scale: _pulseAnim,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _teal.withOpacity(0.22),
                                      _teal.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // rotating dashes ring
                            AnimatedBuilder(
                              animation: _rotateSlow,
                              builder: (_, __) => Transform.rotate(
                                angle: _rotateSlow.value,
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _DashedRingPainter(
                                    color: _teal.withOpacity(0.35),
                                  ),
                                ),
                              ),
                            ),

                            // logo card
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1A2A3F),
                                    Color(0xFF0D1826),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _teal.withOpacity(0.35),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: _cyan.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: _teal.withOpacity(0.3),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Image.asset(
                                'asset/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Brand name ───────────────────────────────────
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_teal, _cyan],
                          ).createShader(bounds),
                          child: const Text(
                            'TECH SOFT',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Headline ─────────────────────────────────────
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _textLight,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account to continue',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textMid,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Glassmorphic form card ────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: _bgCard.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _teal.withOpacity(0.18),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: _teal.withOpacity(0.06),
                                blurRadius: 40,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Teal accent bar ────────────────────
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: const LinearGradient(
                                      colors: [_teal, _cyan],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ── Email ──────────────────────────────
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                      fontSize: 15, color: _textLight),
                                  cursorColor: _teal,
                                  decoration: _inputDeco(
                                    label: 'Email Address',
                                    hint: 'you@example.com',
                                    icon: Icons.email_outlined,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(v)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                // ── Password ───────────────────────────
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                      fontSize: 15, color: _textLight),
                                  cursorColor: _teal,
                                  decoration: _inputDeco(
                                    label: 'Password',
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: GestureDetector(
                                      onTap: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                      child: Padding(
                                        padding:
                                        const EdgeInsets.only(right: 14),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                          color: _textMid,
                                        ),
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 28),
                                // ── Sign In button ─────────────────────
                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          gradient: auth.isLoading
                                              ? null
                                              : const LinearGradient(
                                            colors: [
                                              Color(0xFF00B8AD),
                                              Color(0xFF0EA5E9),
                                            ],
                                          ),
                                          color: auth.isLoading
                                              ? _bgField
                                              : null,
                                          boxShadow: auth.isLoading
                                              ? []
                                              : [
                                            BoxShadow(
                                              color: _teal
                                                  .withOpacity(0.40),
                                              blurRadius: 20,
                                              offset:
                                              const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                          auth.isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                            Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                            Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: auth.isLoading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: _teal,
                                            ),
                                          )
                                              : const Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons
                                                    .arrow_forward_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Footer ────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 1,
                              color: _border,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '© ${DateTime.now().year} Tech Soft. All rights reserved.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _textMid.withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 28,
                              height: 1,
                              color: _border,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background grid painter ─────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2D45).withOpacity(0.35)
      ..strokeWidth = 0.6;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Dashed rotating ring painter ────────────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color color;
  const _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dashCount = 20;
    const dashAngle = 2 * math.pi / dashCount;
    const gapFraction = 0.45;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Glow orb ─────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}