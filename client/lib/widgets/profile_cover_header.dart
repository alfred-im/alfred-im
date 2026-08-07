// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import '../theme/alfred_colors.dart';
import 'profile_identity.dart';

/// Presentazione banner copertina profilo (hero scheda o card sidebar compatta).
enum ProfileCoverPresentation {
  hero,
  compact,
}

/// Stile hero: identità sotto il banner o sovrapposta (overlay peer).
enum ProfileCoverHeroStyle {
  split,
  immersive,
}

/// Banner copertina + avatar sovrapposto — usato in profilo, overlay peer e sidebar.
class ProfileCoverHeader extends StatelessWidget {
  const ProfileCoverHeader({
    super.key,
    required this.profile,
    this.presentation = ProfileCoverPresentation.hero,
    this.heroStyle = ProfileCoverHeroStyle.split,
    this.avatarRadius,
    this.trailing,
    this.overlayTopStart,
    this.overlayTopEnd,
    this.onCoverTap,
    this.onAvatarTap,
    this.coverOverlay,
    this.avatarOverlay,
    this.identityBelowAvatar = true,
    this.nameStyle,
    this.usernameStyle,
    this.pronounsStyle,
    this.showPronouns = true,
    this.showGroupBadge = true,
    this.extraBelowIdentity,
  });

  final ProfileSummary profile;
  final ProfileCoverPresentation presentation;
  final ProfileCoverHeroStyle heroStyle;
  final double? avatarRadius;
  final Widget? trailing;
  final Widget? overlayTopStart;
  final Widget? overlayTopEnd;
  final VoidCallback? onCoverTap;
  final VoidCallback? onAvatarTap;
  final Widget? coverOverlay;
  final Widget? avatarOverlay;
  final bool identityBelowAvatar;
  final TextStyle? nameStyle;
  final TextStyle? usernameStyle;
  final TextStyle? pronounsStyle;
  final bool showPronouns;
  final bool showGroupBadge;
  final Widget? extraBelowIdentity;

  bool get _isCompact => presentation == ProfileCoverPresentation.compact;

  double get _coverHeight {
    if (_isCompact) return 80;
    return heroStyle == ProfileCoverHeroStyle.immersive ? 220 : 140;
  }

  double get _resolvedAvatarRadius => avatarRadius ?? (_isCompact ? 28 : 56);

  double get _avatarFontSize => _resolvedAvatarRadius * (_isCompact ? 0.78 : 0.72);

  double get _compactIdentityLeftPadding =>
      12 + (_resolvedAvatarRadius * 2) + 8;

  @override
  Widget build(BuildContext context) {
    if (_isCompact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    _CoverBackground(
                      coverUrl: profile.coverUrl,
                      height: _coverHeight,
                      borderRadius: 12,
                      onTap: onCoverTap,
                      overlay: coverOverlay,
                    ),
                    if (overlayTopStart != null)
                      Positioned(top: 4, left: 4, child: overlayTopStart!),
                    if (overlayTopEnd != null)
                      Positioned(top: 4, right: 4, child: overlayTopEnd!),
                  ],
                ),
                Container(
                  color: AlfredColors.panel,
                  padding: EdgeInsets.fromLTRB(
                    _compactIdentityLeftPadding,
                    36,
                    8,
                    12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileIdentityLines(
                              profile: profile,
                              nameStyle: nameStyle ??
                                  const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: AlfredColors.textPrimary,
                                  ),
                              usernameStyle: usernameStyle,
                              pronounsStyle: pronounsStyle,
                              showPronouns: showPronouns,
                            ),
                            ?extraBelowIdentity,
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 12,
              top: _coverHeight - _resolvedAvatarRadius,
              child: _AvatarFrame(
                profile: profile,
                radius: _resolvedAvatarRadius,
                fontSize: _avatarFontSize,
                onTap: onAvatarTap,
                overlay: avatarOverlay,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (heroStyle == ProfileCoverHeroStyle.immersive)
          _ImmersiveCoverBody(
            profile: profile,
            minHeight: _coverHeight,
            onCoverTap: onCoverTap,
            coverOverlay: coverOverlay,
            overlayTopStart: overlayTopStart,
            overlayTopEnd: overlayTopEnd,
            avatarRadius: _resolvedAvatarRadius,
            avatarFontSize: _avatarFontSize,
            onAvatarTap: onAvatarTap,
            avatarOverlay: avatarOverlay,
            nameStyle: nameStyle,
            usernameStyle: usernameStyle,
            pronounsStyle: pronounsStyle,
            showPronouns: showPronouns,
            showGroupBadge: showGroupBadge,
            extraBelowIdentity: extraBelowIdentity,
          )
        else ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  _CoverBackground(
                    coverUrl: profile.coverUrl,
                    height: _coverHeight,
                    onTap: onCoverTap,
                    overlay: coverOverlay,
                  ),
                  if (overlayTopStart != null)
                    Positioned(top: 4, left: 4, child: overlayTopStart!),
                  if (overlayTopEnd != null)
                    Positioned(top: 4, right: 4, child: overlayTopEnd!),
                ],
              ),
              if (identityBelowAvatar)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    _resolvedAvatarRadius + 16,
                    20,
                    24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        profile.displayName,
                        textAlign: TextAlign.center,
                        style: nameStyle ??
                            const TextStyle(
                              color: AlfredColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                      ),
                      if (profile.hasUsername) ...[
                        const SizedBox(height: 6),
                        Text(
                          profile.handle,
                          textAlign: TextAlign.center,
                          style: usernameStyle ??
                              const TextStyle(
                                color: AlfredColors.textSecondary,
                                fontSize: 16,
                              ),
                        ),
                      ],
                      if (showPronouns && profile.hasPronouns) ...[
                        const SizedBox(height: 8),
                        Text(
                          profile.pronouns!,
                          textAlign: TextAlign.center,
                          style: pronounsStyle ??
                              const TextStyle(
                                color: AlfredColors.textSecondary,
                                fontSize: 14,
                              ),
                        ),
                      ],
                      if (showGroupBadge && profile.isGroup) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AlfredColors.charcoal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Account gruppo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      ?extraBelowIdentity,
                    ],
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _coverHeight - _resolvedAvatarRadius,
            child: Center(
              child: _AvatarFrame(
                profile: profile,
                radius: _resolvedAvatarRadius,
                fontSize: _avatarFontSize,
                onTap: onAvatarTap,
                overlay: avatarOverlay,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ImmersiveCoverBody extends StatelessWidget {
  const _ImmersiveCoverBody({
    required this.profile,
    required this.minHeight,
    this.onCoverTap,
    this.coverOverlay,
    this.overlayTopStart,
    this.overlayTopEnd,
    required this.avatarRadius,
    required this.avatarFontSize,
    this.onAvatarTap,
    this.avatarOverlay,
    this.nameStyle,
    this.usernameStyle,
    this.pronounsStyle,
    this.showPronouns = true,
    this.showGroupBadge = true,
    this.extraBelowIdentity,
  });

  final ProfileSummary profile;
  final double minHeight;
  final VoidCallback? onCoverTap;
  final Widget? coverOverlay;
  final Widget? overlayTopStart;
  final Widget? overlayTopEnd;
  final double avatarRadius;
  final double avatarFontSize;
  final VoidCallback? onAvatarTap;
  final Widget? avatarOverlay;
  final TextStyle? nameStyle;
  final TextStyle? usernameStyle;
  final TextStyle? pronounsStyle;
  final bool showPronouns;
  final bool showGroupBadge;
  final Widget? extraBelowIdentity;

  @override
  Widget build(BuildContext context) {
    final coverUrl = profile.coverUrl;
    Widget body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: _CoverImageFill(coverUrl: coverUrl),
            ),
            Positioned.fill(
              child: _CoverScrim(coverUrl: coverUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  _AvatarFrame(
                    profile: profile,
                    radius: avatarRadius,
                    fontSize: avatarFontSize,
                    onTap: onAvatarTap,
                    overlay: avatarOverlay,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    profile.displayName,
                    textAlign: TextAlign.center,
                    style: nameStyle ??
                        const TextStyle(
                          color: AlfredColors.textOnDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                  ),
                  if (profile.hasUsername) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.handle,
                      textAlign: TextAlign.center,
                      style: usernameStyle ??
                          TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 16,
                          ),
                    ),
                  ],
                  if (showPronouns && profile.hasPronouns) ...[
                    const SizedBox(height: 8),
                    Text(
                      profile.pronouns!,
                      textAlign: TextAlign.center,
                      style: pronounsStyle ??
                          TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 14,
                          ),
                    ),
                  ],
                  if (showGroupBadge && profile.isGroup) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Account gruppo',
                        style: TextStyle(
                          color: AlfredColors.textOnDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  ?extraBelowIdentity,
                ],
              ),
            ),
            if (overlayTopStart != null)
              Positioned(top: 4, left: 4, child: overlayTopStart!),
            if (overlayTopEnd != null)
              Positioned(top: 4, right: 4, child: overlayTopEnd!),
            ?coverOverlay,
          ],
        ),
      ),
    );

    if (onCoverTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onCoverTap, child: body),
      );
    }

    return body;
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({
    required this.coverUrl,
    required this.height,
    this.borderRadius = 0,
    this.onTap,
    this.overlay,
  });

  final String? coverUrl;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final border = borderRadius > 0
        ? BorderRadius.vertical(top: Radius.circular(borderRadius))
        : null;

    Widget child = ClipRRect(
      borderRadius: border ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverImageFill(coverUrl: coverUrl),
            _CoverScrim(coverUrl: coverUrl),
            ?overlay,
          ],
        ),
      ),
    );

    if (onTap != null) {
      child = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child),
      );
    }

    return child;
  }
}

class _CoverImageFill extends StatelessWidget {
  const _CoverImageFill({required this.coverUrl});

  final String? coverUrl;

  static const _fallbackGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AlfredColors.charcoal,
      AlfredColors.charcoalActive,
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) {
      return const DecoratedBox(decoration: BoxDecoration(gradient: _fallbackGradient));
    }

    return Image.network(
      coverUrl!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      webHtmlElementStrategy:
          kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        return const DecoratedBox(decoration: BoxDecoration(gradient: _fallbackGradient));
      },
    );
  }
}

class _CoverScrim extends StatelessWidget {
  const _CoverScrim({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: coverUrl == null ? 0 : 0.15),
            Colors.black.withValues(alpha: coverUrl == null ? 0 : 0.45),
          ],
        ),
      ),
    );
  }
}

class _AvatarFrame extends StatelessWidget {
  const _AvatarFrame({
    required this.profile,
    required this.radius,
    required this.fontSize,
    this.onTap,
    this.overlay,
  });

  final ProfileSummary profile;
  final double radius;
  final double fontSize;
  final VoidCallback? onTap;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 3,
        ),
      ),
      child: ProfileAvatar(
        profile: profile,
        radius: radius,
        fontSize: fontSize,
      ),
    );

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    if (overlay == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        avatar,
        overlay!,
      ],
    );
  }
}
