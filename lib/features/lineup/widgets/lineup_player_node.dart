import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';

const Color _goldColor = AppColors.secondary;
const Color _chalkColor = AppColors.textPrimaryTinted;

class LineupPlayerNode extends StatelessWidget {
  final LineupPlayer? player;
  final SlotRole role;
  final bool isSelected;
  final bool isDragging;
  final bool isUnavailable;
  final bool compact;
  final bool presentationMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? xCoordinate;
  final Animation<double>? shimmerAnimation; // Shared shimmer controller

  const LineupPlayerNode({
    super.key,
    required this.player,
    required this.role,
    this.isSelected = false,
    this.isDragging = false,
    this.isUnavailable = false,
    this.compact = false,
    this.presentationMode = false,
    this.onTap,
    this.onLongPress,
    this.xCoordinate,
    this.shimmerAnimation,
  });

  bool get isEmpty => player == null;

  @override
  Widget build(BuildContext context) {
    final nodeWidth = compact ? 64.0 : 76.0;
    final borderColor = lineupRoleColor(role);
    final label = isEmpty ? 'إضافة لاعب' : lineupDisplayName(player!);

    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          opacity: isUnavailable ? 0.45 : 1,
          duration: const Duration(milliseconds: 160),
          child: AnimatedScale(
            scale: isDragging ? 1.08 : 1,
            duration: const Duration(milliseconds: 160),
            child: SizedBox(
              width: nodeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AvatarSection(
                    player: player,
                    borderColor: borderColor,
                    isSelected: isSelected,
                    isEmpty: isEmpty,
                    compact: compact,
                    presentationMode: presentationMode,
                    shimmerAnimation: shimmerAnimation,
                    role: role,
                  ),
                  const SizedBox(height: 5),
                  _TacticalCard(
                    player: player,
                    role: role,
                    borderColor: borderColor,
                    isEmpty: isEmpty,
                    compact: compact,
                    presentationMode: presentationMode,
                    nodeWidth: nodeWidth,
                    xCoordinate: xCoordinate,
                    shimmerAnimation: shimmerAnimation,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final LineupPlayer? player;
  final Color borderColor;
  final bool isSelected;
  final bool isEmpty;
  final bool compact;
  final bool presentationMode;
  final Animation<double>? shimmerAnimation;
  final SlotRole role;

  const _AvatarSection({
    required this.player,
    required this.borderColor,
    required this.isSelected,
    required this.isEmpty,
    required this.compact,
    required this.presentationMode,
    this.shimmerAnimation,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = compact ? 56.0 : 66.0;
    final cardHeight = compact ? 56.0 : 66.0;

    if (isEmpty) {
      final size = compact ? 36.0 : 44.0;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              borderColor.withValues(alpha: 0.18),
              borderColor.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.55),
            width: isSelected ? 2.2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          color: borderColor.withValues(alpha: 0.78),
          size: compact ? 22 : 26,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Ground the player card visually on the pitch.
        Positioned(
          bottom: -2,
          child: Container(
            width: cardWidth * 0.85,
            height: 10.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(cardWidth * 0.85, 10.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 9.0,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        ),

        _JerseyWidget(
          player: player!,
          width: cardWidth,
          height: cardHeight,
          compact: compact,
          roleColor: borderColor,
          isSelected: isSelected,
          shimmerAnimation: shimmerAnimation,
          role: role,
        ),

        // Badges overlays
        if (player!.isCaptain)
          PositionedDirectional(
            bottom: -2,
            start: -2,
            child: _MiniBadge(
              label: 'C',
              color: AppColors.backgroundDeep,
              background: _goldColor,
            ),
          ),
        if (player!.isTemporary || player!.isGuest)
          PositionedDirectional(
            bottom: -2,
            end: -8,
            child: _MiniBadge(
              label: player!.isTemporary ? 'مؤقت' : 'ضيف',
              color: AppColors.backgroundDeep,
              background: AppColors.warning,
            ),
          ),
      ],
    );
  }
}

class _JerseyWidget extends StatelessWidget {
  final LineupPlayer player;
  final double width;
  final double height;
  final bool compact;
  final Color roleColor;
  final bool isSelected;
  final Animation<double>? shimmerAnimation;
  final SlotRole? role;

  const _JerseyWidget({
    required this.player,
    required this.width,
    required this.height,
    required this.compact,
    required this.roleColor,
    required this.isSelected,
    this.shimmerAnimation,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final numberText = player.number != null
        ? '${player.number}'
        : _getFallbackNumber(role, player.id);

    final String displayName = lineupDisplayName(player);
    final String shortName = _extractShortLatinName(displayName).toUpperCase();
    final photoUrl = player.photoUrl;

    final baseJersey = SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StreetJerseyPainter(
                baseColor: roleColor,
                selected: isSelected,
              ),
            ),
          ),

          if (photoUrl != null && photoUrl.isNotEmpty)
            Positioned(
              top: height * 0.35,
              child: Container(
                width: compact ? 18.0 : 22.0,
                height: compact ? 18.0 : 22.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _chalkColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: roleColor.withValues(alpha: 0.28),
                      blurRadius: 4,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      _buildJerseyTexts(shortName, numberText, _chalkColor),
                  errorWidget: (context, url, error) =>
                      _buildJerseyTexts(shortName, numberText, _chalkColor),
                ),
              ),
            )
          else
            Positioned.fill(
              child: _buildJerseyTexts(shortName, numberText, _chalkColor),
            ),
        ],
      ),
    );

    if (shimmerAnimation == null) {
      return baseJersey;
    }

    return AnimatedBuilder(
      animation: shimmerAnimation!,
      builder: (context, child) {
        final double shimmerVal = shimmerAnimation!.value;
        final double pos = -0.4 + (shimmerVal * 1.8);
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                roleColor.withValues(alpha: 0.24),
                Colors.transparent,
              ],
              stops: [
                (pos - 0.18).clamp(0.0, 1.0),
                pos.clamp(0.0, 1.0),
                (pos + 0.18).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: baseJersey,
    );
  }

  Widget _buildJerseyTexts(
    String shortName,
    String numberText,
    Color chalkColor,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: height * 0.58,
          child: Text(
            shortName,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: chalkColor.withValues(alpha: 0.95),
              fontSize: compact ? 6.0 : 7.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        Positioned(
          top: height * 0.66,
          child: Text(
            numberText,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: chalkColor,
              fontSize: compact ? 11.0 : 13.0,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  String _extractShortLatinName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'PLAYER';
    final parts = clean.split(RegExp(r'\s+'));

    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(clean);
    if (hasArabic) {
      if (parts.length >= 2) {
        return '${parts[0][0]}. ${parts[1]}';
      }
      return parts.first;
    }

    if (parts.length >= 2) {
      final firstLetter = parts.first[0];
      return '$firstLetter ${parts[1]}';
    }
    return parts.first;
  }

  String _getFallbackNumber(SlotRole? role, String playerId) {
    final hash = playerId.hashCode.abs();
    if (role == null) return '9';
    return switch (role) {
      SlotRole.gk => '1',
      SlotRole.def => const ['2', '3', '4', '5', '12', '13'][hash % 6],
      SlotRole.mid => const ['6', '7', '8', '10', '14', '20', '22'][hash % 7],
      SlotRole.att => const ['9', '11', '17', '18', '21'][hash % 5],
    };
  }
}

class _StreetJerseyPainter extends CustomPainter {
  final Color baseColor;
  final bool selected;

  const _StreetJerseyPainter({required this.baseColor, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final body = Path()
      ..moveTo(size.width * 0.31, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.12,
        size.width * 0.69,
        size.height * 0.24,
      )
      ..lineTo(size.width * 0.82, size.height * 0.42)
      ..lineTo(size.width * 0.72, size.height * 0.53)
      ..lineTo(size.width * 0.72, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.94,
        size.width * 0.28,
        size.height * 0.86,
      )
      ..lineTo(size.width * 0.28, size.height * 0.53)
      ..lineTo(size.width * 0.18, size.height * 0.42)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withValues(alpha: 0.95),
          baseColor.withValues(alpha: 0.62),
          AppColors.backgroundDeep.withValues(alpha: 0.92),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(body, fill);

    final collar = Path()
      ..moveTo(size.width * 0.38, size.height * 0.23)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.33,
        size.width * 0.62,
        size.height * 0.23,
      );
    canvas.drawPath(
      collar,
      Paint()
        ..color = AppColors.backgroundDeep.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final seam = Paint()
      ..color = AppColors.textPrimaryTinted.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.34),
      Offset(size.width * 0.50, size.height * 0.82),
      seam,
    );
    canvas.drawPath(body, seam);

    if (selected) {
      canvas.drawPath(
        body,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreetJerseyPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.selected != selected;
  }
}

class _TacticalCard extends StatelessWidget {
  final LineupPlayer? player;
  final SlotRole role;
  final Color borderColor;
  final bool isEmpty;
  final bool compact;
  final bool presentationMode;
  final double nodeWidth;
  final double? xCoordinate;
  final Animation<double>? shimmerAnimation; // Shared shimmer controller

  const _TacticalCard({
    required this.player,
    required this.role,
    required this.borderColor,
    required this.isEmpty,
    required this.compact,
    required this.presentationMode,
    required this.nodeWidth,
    this.xCoordinate,
    this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorderColor = isEmpty
        ? borderColor.withValues(alpha: 0.28)
        : _goldColor.withValues(alpha: 0.55);

    final cardBgColor = isEmpty
        ? const Color(0xB30D130F)
        : const Color(0xE6080E09);

    final String nameLabel = isEmpty
        ? 'إضافة لاعب'
        : lineupDisplayName(player!);

    final String positionLabel = switch (role) {
      SlotRole.gk => 'حارس مرمى',
      SlotRole.def => _getDefensiveLabel(),
      SlotRole.mid => 'نص ملعب',
      SlotRole.att => _getAttackingLabel(),
    };

    final cardWidget = Container(
      width: nodeWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cardBorderColor, width: isEmpty ? 0.9 : 1.1),
        boxShadow: isEmpty
            ? null
            : [
                BoxShadow(
                  color: _goldColor.withValues(alpha: 0.15),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nameLabel,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            positionLabel,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: isEmpty ? borderColor.withValues(alpha: 0.8) : _goldColor,
              fontSize: compact ? 7.0 : 8.0,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (shimmerAnimation == null || isEmpty) {
      return cardWidget;
    }

    return AnimatedBuilder(
      animation: shimmerAnimation!,
      builder: (context, child) {
        final double shimmerVal = shimmerAnimation!.value;
        final double pos = -0.4 + (shimmerVal * 1.8);
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                const Color(0xFFFFD700).withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: [
                (pos - 0.18).clamp(0.0, 1.0),
                pos.clamp(0.0, 1.0),
                (pos + 0.18).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: cardWidget,
    );
  }

  String _getDefensiveLabel() {
    if (xCoordinate == null) return 'مدافع';
    if (xCoordinate! < 30) return 'ظهير أيسر';
    if (xCoordinate! > 70) return 'ظهير أيمن';
    return 'قلب دفاع';
  }

  String _getAttackingLabel() {
    if (xCoordinate == null) return 'مهاجم';
    if (xCoordinate! < 30) return 'جناح أيسر';
    if (xCoordinate! > 70) return 'جناح أيمن';
    return 'مهاجم صريح';
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _MiniBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}
