import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  void _goHome() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        ),
        title: Text('Rate Your Order', style: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
        actions: [
          TextButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.skip_next_rounded, size: 16),
            label: Text('Skip', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700, color: AppColors.muted)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: const Center(child: Text('🍛', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 12),
            Text('Saoji Kitchen', style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.foreground)),
            Text('Order #LB847291 · Nagpur Jn',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 32),

            Text('How was your experience?', style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: AnimatedScale(
                  scale: _rating >= i + 1 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('⭐',
                      style: TextStyle(
                        fontSize: 36,
                        color: _rating >= i + 1 ? null : Colors.black,
                      ).copyWith(
                        shadows: _rating < i + 1
                          ? [const Shadow(color: Colors.transparent, blurRadius: 0)]
                          : null,
                      ),
                    ),
                  ),
                ),
              )),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!'][_rating],
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],

            const SizedBox(height: 28),
            Align(alignment: Alignment.centerLeft, child: Text('ADD A COMMENT (OPTIONAL)',
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: AppColors.muted, letterSpacing: 1.5))),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                hintStyle: GoogleFonts.nunito(
                  color: AppColors.muted.withOpacity(0.5), fontSize: 13),
                filled: true, fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.primaryLight)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.primaryLight)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: _rating > 0 ? _goHome : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryLight,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: _rating > 0 ? 8 : 0,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: Text('Submit Rating',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
