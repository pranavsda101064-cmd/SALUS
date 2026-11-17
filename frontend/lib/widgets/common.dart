import '../icons.dart';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

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
    final effectiveBorder =
        borderColor ??
        (highlight == null
            ? SalusColors.border
            : highlight!.withValues(alpha: 0.5));
    final effectiveFill = highlight == null
        ? SalusColors.surface
        : Color.alphaBlend(
            highlight!.withValues(alpha: 0.06),
            SalusColors.surface,
          );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );
    if (onTap == null) return FadeSlideIn(offset: 12, child: content);
    return FadeSlideIn(
      offset: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class SalusBadge extends StatelessWidget {
  const SalusBadge({
    super.key,
    required this.label,
    this.color = SalusColors.cobalt,
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
    final isPrimary = color == SalusColors.primary;
    final useFill = filled || isPrimary;
    final textColor = useFill ? SalusColors.onPrimary : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: useFill ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: useFill
              ? SalusColors.ink.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.35),
        ),
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
              fontSize: small ? 10 : 11.5,
              fontWeight: FontWeight.w600,
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
      color: SalusColors.muted,
      icon: SalusIcons.flask,
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
    this.mark,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? eyebrow;
  final String? mark;

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
                    color: SalusColors.cobalt,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              mark == null
                  ? Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  : HighlightedText(
                      text: title,
                      mark: mark!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: SalusColors.muted,
                    height: 1.45,
                  ),
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
    this.color = SalusColors.cobalt,
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
                    fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(color: SalusColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
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
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: SalusColors.muted,
                    fontSize: 12.5,
                  ),
                ),
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
            child: Text(
              label,
              style: const TextStyle(color: SalusColors.muted, fontSize: 13),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SalusColors.cobalt.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  factor,
                  style: const TextStyle(
                    color: SalusColors.cobalt,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$score / 100',
                style: const TextStyle(
                  color: SalusColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 58,
                child: Text(
                  '+${points.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: SalusColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: SalusColors.surfaceSoft,
              valueColor: const AlwaysStoppedAnimation(SalusColors.cobalt),
            ),
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              reason!,
              style: const TextStyle(
                color: SalusColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatItem {
  const StatItem({
    required this.label,
    required this.value,
    this.hint,
    this.color = SalusColors.text,
  });

  final String label;
  final String value;
  final String? hint;
  final Color color;
}

class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});
  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: _StatCell(item: items[index]),
                  ),
                ],
              ],
            );
          }
          return Row(
            children: [
              const SizedBox(width: 20),
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  Container(
                    width: 1,
                    height: 56,
                    color: SalusColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: _StatCell(item: items[index]),
                  ),
                ),
              ],
              const SizedBox(width: 20),
            ],
          );
        },
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.item});
  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final isPrimary = item.color == SalusColors.primary;
    final value = CountingText(
      text: item.value,
      style: TextStyle(
        color: isPrimary ? SalusColors.onPrimary : item.color,
        fontSize: 24,
        height: 30 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label.toUpperCase(),
          style: const TextStyle(
            color: SalusColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        if (isPrimary)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: SalusColors.primary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: SalusColors.ink.withValues(alpha: 0.16),
              ),
            ),
            child: value,
          )
        else
          value,
        if (item.hint != null) ...[
          const SizedBox(height: 3),
          Text(
            item.hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
          ),
        ],
      ],
    );
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
            if (action != null) ...[const SizedBox(height: 18), action!],
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
      borderColor: SalusColors.primary,
      child: Row(
        children: [
          const Icon(SalusIcons.warningCircle, color: SalusColors.yellow),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: SalusColors.text),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
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
  const RefChip({
    super.key,
    required this.type,
    required this.id,
    this.simulated = false,
  });
  final String type;
  final String id;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final isMatch = type == 'MATCH';
    final background = isMatch
        ? SalusColors.primary
        : SalusColors.secondarySoft;
    final foreground = isMatch ? SalusColors.ink : SalusColors.secondary;
    final outline = isMatch
        ? SalusColors.ink.withValues(alpha: 0.16)
        : SalusColors.secondary.withValues(alpha: 0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: TextStyle(
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            id,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (simulated) ...[
            const SizedBox(width: 5),
            Icon(
              SalusIcons.flask,
              size: 10,
              color: foreground.withValues(alpha: 0.65),
            ),
          ],
        ],
      ),
    );
  }
}
