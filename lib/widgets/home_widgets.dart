import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded filter chip: white with a tinted icon when idle, solid blue when
/// selected.
class AppPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const AppPill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyle.radiusPill),
        elevation: selected ? 0 : 2,
        shadowColor: const Color(0x261F5FA8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyle.radiusPill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.tint,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded search field with a leading magnifier.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyle.radiusMd + 2),
        boxShadow: AppStyle.softShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/// A faint circle cluster that stands in for the illustration on the
/// reference design's cards. Pure decoration, hidden from screen readers.
class _CardDecoration extends StatelessWidget {
  final double size;
  const _CardDecoration({required this.size});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              right: -size * 0.25,
              top: -size * 0.25,
              child: _circle(size * 0.95, 0.10),
            ),
            Positioned(
              right: size * 0.18,
              bottom: -size * 0.28,
              child: _circle(size * 0.6, 0.10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double d, double alpha) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// Small translucent-white info pill used on gradient cards ("10 questions").
class _CardMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CardMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppStyle.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient card surface shared by [SectionCard] and [HeroBanner].
///
/// The drop shadow lives on an outer box and the gradient + ripple are clipped
/// by an inner [Material]; putting the shadow inside the clipped layer would
/// cut it off at the card's rectangle and leave visible hard edges.
class _GradientSurface extends StatelessWidget {
  final double radius;
  final List<Color> colors;
  final double shadowBlur;
  final double shadowOffset;
  final double decorationSize;
  final VoidCallback onTap;
  final Widget child;

  const _GradientSurface({
    required this.radius,
    required this.colors,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.decorationSize,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.30),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(child: _CardDecoration(size: decorationSize)),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tall gradient card used in the horizontal "Practice by section" row.
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final IconData metaIcon;
  final List<Color> colors;
  final VoidCallback onTap;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.colors,
    required this.onTap,
    this.metaIcon = Icons.help_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle. $meta',
      child: ExcludeSemantics(
        child: _GradientSurface(
          radius: AppStyle.radiusLg,
          colors: colors,
          shadowBlur: 22,
          shadowOffset: 10,
          onTap: onTap,
          decorationSize: 150,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: Colors.white, size: 25),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _CardMeta(icon: metaIcon, text: meta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide gradient banner: headline, one line of detail and a white pill button.
/// Used for today's Daily Sprint and for the Mock Test.
class HeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle. $buttonLabel',
      child: ExcludeSemantics(
        child: _GradientSurface(
          radius: AppStyle.radiusXl,
          colors: colors,
          shadowBlur: 24,
          shadowOffset: 12,
          onTap: onTap,
          decorationSize: 190,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppStyle.radiusPill),
                        ),
                        child: Text(
                          buttonLabel,
                          style: TextStyle(
                            color: colors.last,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: Icon(icon, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Floating white bottom bar. The selected item expands into a blue pill with
/// its label, the rest are icon-only (with tooltips for accessibility).
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppStyle.radiusXl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E1F5FA8),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavButton(
                    item: items[i],
                    selected: i == selected,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppStyle.radiusPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppStyle.radiusPill),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 14,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 23,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
