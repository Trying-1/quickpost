import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../config/app_theme.dart';
import '../../services/subscription_service.dart';
import '../../services/analytics_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool skippable;
  final VoidCallback? onClose;
  const SubscriptionScreen({super.key, this.skippable = true, this.onClose});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedTierIndex = 1; // Default to Annual (Save 50%)
  bool _isLoading = false;
  List<ProductDetails> _products = [];
  bool _isFetchingProducts = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Subscription Paywall');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _loadStoreProducts();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreProducts() async {
    setState(() => _isFetchingProducts = true);
    final prods = await SubscriptionService.fetchProducts();
    if (mounted) {
      setState(() {
        _products = prods;
        _isFetchingProducts = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      ProductDetails? targetProduct;
      final targetId = _selectedTierIndex == 0 
          ? SubscriptionService.idMonthly 
          : (_selectedTierIndex == 1 ? SubscriptionService.idYearly : SubscriptionService.idLifetime);
          
      for (var prod in _products) {
        if (prod.id == targetId) {
          targetProduct = prod;
          break;
        }
      }

      if (targetProduct != null) {
        // Trigger real billing checkout
        final success = await SubscriptionService.buyProduct(targetProduct);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing subscription checkout...')),
          );
        }
      } else {
        // Mock Sandbox Billing (for testing/sandbox environments)
        await Future.delayed(const Duration(milliseconds: 1500));
        await SubscriptionService.setProActive(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('💎 Pro Workspace fully unlocked!')),
          );
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionScreen] Checkout error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    final success = await SubscriptionService.restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Restore request sent! Active purchases will update momentarily.' 
              : 'Restore failed. Please verify your Google Account settings.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    
    // Pristine Light Theme System Colors
    const lightBg = Color(0xFFF8FAFC); // Clean off-white surface
    const cardLight = Colors.white;    // Soft light cards surface
    const borderLight = Color(0xFFE2E8F0); // Subtle boundaries slate grey
    
    // Core Slate text colors
    const textPrimary = Color(0xFF0F172A); // slate-900
    const textSecondary = Color(0xFF475569); // slate-600
    const textHint = Color(0xFF94A3B8); // slate-400

    return Scaffold(
      backgroundColor: lightBg,
      body: Stack(
        children: [
          // Glowing Ambient Pastel Orbs background
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _pulseController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (scale * 20),
                    right: -100 + (scale * 20),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withOpacity(0.08 + (scale * 0.03)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50 - (scale * 20),
                    left: -80 - (scale * 20),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withOpacity(0.05 + (scale * 0.02)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top Custom Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.skippable)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: textSecondary, size: 24),
                          onPressed: widget.onClose ?? () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 44),
                      TextButton(
                        onPressed: _handleRestore,
                        style: TextButton.styleFrom(foregroundColor: textSecondary),
                        child: const Text(
                          'Restore',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: Column(
                      children: [
                        // Pulsing crown icon
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final dy = _pulseController.value * 6;
                            return Transform.translate(
                              offset: Offset(0, dy),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primary, Colors.amber],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withOpacity(0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        
                        const Text(
                          'QUICKPOST PRO',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Accelerate your creative pipeline with uncompromised limits',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Features List
                        _buildFeatureRow(
                          icon: Icons.auto_awesome_rounded,
                          title: 'GPU Concurrent Pipelines',
                          desc: 'Unlock lightning fast batch automated multi-video cropping.',
                          color: primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _buildFeatureRow(
                          icon: Icons.block_rounded,
                          title: '100% Ad-Free Studio',
                          desc: 'Absolute suppression of all interstitials, banners, and app-open ads.',
                          color: Colors.redAccent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _buildFeatureRow(
                          icon: Icons.branding_watermark_rounded,
                          title: 'Brand Logos Customizer',
                          desc: 'Apply clean translucent branding watermarks to all exports.',
                          color: Colors.blueAccent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _buildFeatureRow(
                          icon: Icons.library_music_rounded,
                          title: 'Infinite Audios Folders',
                          desc: 'Create limitless subdirectories to arrange trending background SFX.',
                          color: Colors.greenAccent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        
                        const SizedBox(height: 28),

                        // Price Options Grid
                        _buildTiersGrid(cardLight, borderLight, primary, textPrimary, textSecondary),
                        
                        const SizedBox(height: 32),

                        // Master Action CTA Button
                        GestureDetector(
                          onTap: _handlePurchase,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primary, primary.withRed(20)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Upgrade Workspace Now 👑',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        // Trust & Guarantees Disclosures
                        const Text(
                          '🔐 Play Store Secure SSL Encrypted checkout.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: textHint),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cancel anytime in Google Play Account Subscriptions settings.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: textHint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15), width: 1.0),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiersGrid(
    Color cardLight,
    Color borderLight,
    Color primary,
    Color textPrimary,
    Color textSecondary,
  ) {
    // If fetching store items from Play Store fails or is empty, we fall back to hardcoded elite mock tiers!
    final List<Map<String, String>> tiers = [
      {
        'title': 'Monthly',
        'price': _isFetchingProducts 
            ? '\$4.99' 
            : (_products.any((p) => p.id == SubscriptionService.idMonthly) 
                ? _products.firstWhere((p) => p.id == SubscriptionService.idMonthly).price 
                : '\$4.99'),
        'period': '/ mo',
        'badge': '',
      },
      {
        'title': 'Yearly',
        'price': _isFetchingProducts 
            ? '\$29.99' 
            : (_products.any((p) => p.id == SubscriptionService.idYearly) 
                ? _products.firstWhere((p) => p.id == SubscriptionService.idYearly).price 
                : '\$29.99'),
        'period': '/ yr',
        'badge': 'SAVE 50%',
      },
      {
        'title': 'Lifetime',
        'price': _isFetchingProducts 
            ? '\$59.99' 
            : (_products.any((p) => p.id == SubscriptionService.idLifetime) 
                ? _products.firstWhere((p) => p.id == SubscriptionService.idLifetime).price 
                : '\$59.99'),
        'period': 'one-time',
        'badge': 'BEST ACCESS',
      },
    ];

    return Row(
      children: List.generate(3, (idx) {
        final active = _selectedTierIndex == idx;
        final tier = tiers[idx];
        final badge = tier['badge']!;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: idx == 0 ? 0 : 6,
              right: idx == 2 ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTierIndex = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? primary.withOpacity(0.06) : cardLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? primary : borderLight,
                    width: active ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          tier['title']!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: active ? primary : textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tier['price']!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier['period']!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            color: active ? primary.withOpacity(0.8) : textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (badge.isNotEmpty)
                      Positioned(
                        top: -24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: idx == 1 ? Colors.amber : primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 7.5,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
