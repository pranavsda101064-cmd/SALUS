import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../theme.dart';

/// Base curve from the landing skill. Weighted, decelerates into place.
const Curve salusEase = Cubic(0.22, 1.0, 0.36, 1.0);

bool salusReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Fades and lifts a child into place once. Runs after [delay] so a column of
/// cards arrives in reading order. Shows the final state at once when the
/// system asks for reduced motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 20,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: salusEase,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (salusReduceMotion(context)) {
      _controller.value = 1;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        final t = _curved.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Text with a flat highlighter stroke behind the [mark] phrase. The stroke is
/// a background colour on the span, so there is no gradient and no extra layer.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.mark,
    this.style,
    this.textAlign,
  });

  final String text;
  final String mark;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final index = text.indexOf(mark);
    if (mark.isEmpty || index < 0) {
      return Text(text, style: style, textAlign: textAlign);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: mark,
            style: TextStyle(
              background: Paint()
                ..color = SalusColors.primary.withValues(alpha: 0.9),
            ),
          ),
          TextSpan(text: text.substring(index + mark.length)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Text that counts up to a number once it appears. Non numeric text, such as
/// "Template" or "Gemini", is shown unchanged.
class CountingText extends StatelessWidget {
  const CountingText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  static final RegExp _digits = RegExp(r'^[0-9,]+$');

  @override
  Widget build(BuildContext context) {
    final clean = text.replaceAll(',', '');
    if (!_digits.hasMatch(text) ||
        clean.isEmpty ||
        salusReduceMotion(context)) {
      return Text(text, style: style);
    }
    final target = double.parse(clean);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 1100),
      curve: salusEase,
      builder: (context, value, _) {
        return Text(_grouped(value.round()), style: style);
      },
    );
  }

  static String _grouped(int number) {
    final digits = number.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class CarouselSlide {
  const CarouselSlide({
    required this.asset,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onAction,
    this.icon,
    this.semanticLabel,
  });

  final String asset;
  final String eyebrow;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final String? semanticLabel;
}

/// A card carousel with parallax photos and a 6 second autoplay driven by a
/// progress bar. Autoplay pauses while the pointer is over it or focus is
/// inside, and is off under reduced motion. Arrow keys, Home and End work when
/// the carousel has focus.
class ParallaxCarousel extends StatefulWidget {
  const ParallaxCarousel({
    super.key,
    required this.slides,
    this.autoplayInterval = const Duration(seconds: 6),
    this.imageHeight = 210,
    this.autoplay = true,
  });

  final List<CarouselSlide> slides;
  final Duration autoplayInterval;
  final double imageHeight;
  final bool autoplay;

  @override
  State<ParallaxCarousel> createState() => _ParallaxCarouselState();
}

class _ParallaxCarouselState extends State<ParallaxCarousel>
    with TickerProviderStateMixin {
  late final PageController _controller = PageController(
    viewportFraction: 0.82,
  );
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.autoplayInterval,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'carousel');
  int _index = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _reduce = false;
  late bool _autoplay = widget.autoplay;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _advance();
    });
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = salusReduceMotion(context);
    final changed = !_started || reduce != _reduce;
    _started = true;
    _reduce = reduce;
    if (reduce) _autoplay = false;
    if (changed) _syncAutoplay();
  }

  @override
  void dispose() {
    _progress.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _paused =>
      _hovered || _focused || !_autoplay || _reduce || widget.slides.length < 2;

  void _syncAutoplay() {
    if (_paused) {
      _progress.stop();
    } else if (!_progress.isAnimating) {
      _progress.forward(from: _progress.value);
    }
  }

  void _restartProgress() {
    _progress.value = 0;
    _syncAutoplay();
  }

  void _advance() {
    _goTo(_index + 1);
    _restartProgress();
  }

  void _goTo(int target) {
    if (!_controller.hasClients || widget.slides.isEmpty) return;
    final count = widget.slides.length;
    final next = ((target % count) + count) % count;
    _controller.animateToPage(
      next,
      duration: _reduce
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 700),
      curve: salusEase,
    );
  }

  void _userMoved(int target) {
    _goTo(target);
    _restartProgress();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _userMoved(_index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _userMoved(_index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _userMoved(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _userMoved(widget.slides.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        _focused = hasFocus;
        _syncAutoplay();
      },
      child: MouseRegion(
        onEnter: (_) {
          _hovered = true;
          _syncAutoplay();
        },
        onExit: (_) {
          _hovered = false;
          _syncAutoplay();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: widget.imageHeight + 214,
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final page =
                          _controller.hasClients &&
                              _controller.position.haveDimensions
                          ? (_controller.page ?? _index.toDouble())
                          : _index.toDouble();
                      final delta = (page - index).clamp(-1.0, 1.0);
                      final focus = 1 - delta.abs();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Transform.scale(
                          scale: 0.96 + 0.04 * focus,
                          child: Opacity(
                            opacity: 0.7 + 0.3 * focus,
                            child: _SlideCard(
                              slide: slides[index],
                              delta: _reduce ? 0 : delta,
                              imageHeight: widget.imageHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _reduce ? 0 : _progress.value,
                    minHeight: 3,
                    backgroundColor: SalusColors.border,
                    valueColor: const AlwaysStoppedAnimation(
                      SalusColors.secondary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ArrowButton(
                  icon: SalusIcons.caretRight,
                  flip: true,
                  label: 'Previous slide',
                  onPressed: () => _userMoved(_index - 1),
                ),
                const SizedBox(width: 8),
                _ArrowButton(
                  icon: SalusIcons.caretRight,
                  label: 'Next slide',
                  onPressed: () => _userMoved(_index + 1),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        _Dot(active: i == _index, onTap: () => _userMoved(i)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _reduce
                      ? null
                      : () {
                          setState(() => _autoplay = !_autoplay);
                          _restartProgress();
                        },
                  child: Text(_autoplay ? 'Pause autoplay' : 'Start autoplay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.delta,
    required this.imageHeight,
  });

  final CarouselSlide slide;
  final double delta;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SalusColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SalusColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: imageHeight,
            child: ClipRect(
              child: FractionalTranslation(
                translation: Offset(-delta * 0.08, 0),
                child: Transform.scale(
                  scale: 1.16,
                  child: Image.asset(
                    slide.asset,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: slide.semanticLabel,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (slide.icon != null) ...[
                        Icon(
                          slide.icon,
                          size: 14,
                          color: SalusColors.secondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        slide.eyebrow.toUpperCase(),
                        style: const TextStyle(
                          color: SalusColors.secondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slide.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      slide.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SalusColors.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: slide.onAction,
                      icon: const Icon(SalusIcons.arrowRight, size: 15),
                      label: Text(slide.actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.flip = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton.outlined(
        onPressed: onPressed,
        icon: Transform.rotate(
          angle: flip ? math.pi : 0,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: salusEase,
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? SalusColors.secondary : SalusColors.borderStrong,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
