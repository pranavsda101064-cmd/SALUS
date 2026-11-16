import 'package:flutter/material.dart';

import '../theme.dart';

class SalusCard extends StatelessWidget {
  const SalusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.highlight,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? highlight;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlight?.withValues(alpha: 0.16) ?? SalusColors.surface,
            SalusColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? SalusColors.border),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: content,
    );
  }
}

class SalusBadge extends StatelessWidget {
  const SalusBadge({
    super.key,
    required this.label,
    this.color = SalusColors.mint,
    this.icon,
    this.small = false,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool small;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? SalusColors.background : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 11 : 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: small ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key, this.small = true});
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SalusBadge(
      label: 'SIMULATED',
      color: SalusColors.violet,
      icon: Icons.science_outlined,
      small: small,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: SalusColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(color: SalusColors.muted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.color = SalusColors.mint,
    this.icon,
  });

  final String label;
  final String value;
  final String? hint;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: SalusColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(color: SalusColors.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: const TextStyle(color: SalusColors.muted, fontSize: 12.5)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: SalusColors.muted),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: SalusColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? SalusColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RiskFactorBar extends StatelessWidget {
  const RiskFactorBar({
    super.key,
    required this.factor,
    required this.label,
    required this.score,
    required this.points,
    this.reason,
    this.weight,
  });

  final String factor;
  final String label;
  final int score;
  final double points;
  final String? reason;
  final double? weight;

  @override
  Widget build(BuildContext context) {
    final color = _factorColor(factor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  factor,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${score.toString()} / 100',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Text(
                  '+${points.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: SalusColors.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: SalusColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(reason!, style: const TextStyle(color: SalusColors.muted, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }

  static Color _factorColor(String factor) {
    switch (factor) {
      case 'S':
        return SalusColors.red;
      case 'D':
        return SalusColors.amber;
      case 'B':
        return SalusColors.blue;
      default:
        return SalusColors.violet;
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: SalusColors.muted),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SizedBox(
              width: 440,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SalusColors.muted, height: 1.45),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      borderColor: SalusColors.red.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SalusColors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: SalusColors.text))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key, this.label = 'Loading evidence'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: SalusColors.muted)),
        ],
      ),
    );
  }
}

class RefChip extends StatelessWidget {
  const RefChip({super.key, required this.type, required this.id, this.simulated = false});
  final String type;
  final String id;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final color = type == 'MATCH' ? SalusColors.amber : SalusColors.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            id,
            style: const TextStyle(
              color: SalusColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (simulated) ...[
            const SizedBox(width: 6),
            const Icon(Icons.science_outlined, size: 11, color: SalusColors.violet),
          ],
        ],
      ),
    );
  }
}
