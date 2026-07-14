// ═══════════════════════════════════════════════════════════════
//  lib/widgets/ad_banner.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme/app_theme.dart';

// Flip to false to serve real ads. Google's test ad unit ID always serves
// test creatives regardless of which App ID is in AndroidManifest.xml, so
// this is the only switch needed before publishing.
const _useTestAds = true;

// Google's public test banner ad unit — always serves test creatives,
// safe to ship in dev/QA builds.
const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

// Real Moon Farm banner ad unit, from the AdMob console.
const _prodBannerAdUnitId = 'ca-app-pub-3075619018847314/6942872354';

const _bannerAdUnitId = _useTestAds ? _testBannerAdUnitId : _prodBannerAdUnitId;

/// Loads and displays a real (test) AdMob banner at [size], matching the
/// footprint of the placeholder it replaces. Renders nothing until the ad
/// loads, and collapses back to nothing if the load fails, so callers don't
/// need to reserve space themselves.
class AdBannerWidget extends StatefulWidget {
  final AdSize size;

  const AdBannerWidget({super.key, this.size = AdSize.banner});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    BannerAd(
      size: widget.size,
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _failed = true);
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) {
      // Loading or failed — collapse to nothing rather than showing a
      // dead grey box, except while we can still reserve the exact size.
      return _failed
          ? const SizedBox.shrink()
          : SizedBox(width: widget.size.width.toDouble(), height: widget.size.height.toDouble());
    }
    return Container(
      alignment: Alignment.center,
      width: widget.size.width.toDouble(),
      height: widget.size.height.toDouble(),
      decoration: BoxDecoration(
        color: MFColors.surface,
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: AdWidget(ad: ad),
    );
  }
}
