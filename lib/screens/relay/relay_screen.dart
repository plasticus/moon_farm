// ═══════════════════════════════════════════════════════════════
//  lib/screens/relay/relay_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../engine/kovacs_engine.dart';
import '../../utils/game_factory.dart';

// ─── Relay Tab Enum ───────────────────────────────────────────────────────────

enum RelayTab { comms, sell, buy, contracts }

// ─── Main Relay Screen ────────────────────────────────────────────────────────

class RelayScreen extends ConsumerStatefulWidget {
  const RelayScreen({super.key});

  @override
  ConsumerState<RelayScreen> createState() => _RelayScreenState();
}

class _RelayScreenState extends ConsumerState<RelayScreen> {
  RelayTab _tab = RelayTab.comms;
  final Map<String, double> _saleQueue = {};

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    final conversation = ref.watch(kovacsConversationProvider);
    final tabsUnlocked = game.relay.conversationDoneThisWeek;

    // Start conversation once per week — only if not already started
    if (_tab == RelayTab.comms && conversation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(kovacsConversationProvider) == null) {
          _initConversation(game);
        }
      });
    }

    return Column(
      children: [
        _KovacsHeader(game: game),
        _RelayTabBar(
          currentTab: _tab,
          tabsUnlocked: tabsUnlocked,
          onTabSelected: (t) {
            if (t != RelayTab.comms && !tabsUnlocked) return;
            setState(() => _tab = t);
          },
        ),
        Expanded(child: _buildBody(game, tabsUnlocked, conversation)),
      ],
    );
  }

  Widget _buildBody(GameState game, bool tabsUnlocked, KovacsConversation? conversation) {
    switch (_tab) {
      case RelayTab.comms:
        return _ConversationTab(
          game: game,
          conversation: conversation,
          onPlayerPicked: (line) => _handlePlayerPicked(line, game),
        );
      case RelayTab.sell:
        return _SellTab(
          game: game,
          saleQueue: _saleQueue,
          onQueueChanged: (cropId, amount) {
            setState(() {
              if (amount <= 0) _saleQueue.remove(cropId);
              else _saleQueue[cropId] = amount;
            });
          },
          onConfirmShipment: _doConfirmShipment,
          onSellAll: _doSellAll,
          onScrapSell: _doScrapSell,
        );
      case RelayTab.buy:
        return _BuyTab(game: game, onBuy: _doBuy);
      case RelayTab.contracts:
        return _ContractsTab(
          game: game,
          onAcceptContract: _doAcceptContract,
          onSubmitToContract: _doSubmitToContract,
        );
    }
  }

  // ─── Conversation management ──────────────────────────────────────────────

  void _initConversation(GameState game) {
    final events = _getContextualEvents(game);
    final conv = KovacsEngine.startConversation(
      game: game,
      unlockedTopicIds: game.relay.unlockedTopicIds,
      contextualEvents: events,
    );
    ref.read(kovacsConversationProvider.notifier).state = conv;
  }

  Set<String> _getContextualEvents(GameState game) {
    final events = <String>{};
    if (game.silosNearFull) events.add('silo_full');
    if (game.isShipWindowOpen) events.add('ship_window_open');
    // raid/milestone events would be passed in from game state
    return events;
  }

  void _handlePlayerPicked(PlayerLine line, GameState game) {
    final conv = ref.read(kovacsConversationProvider);
    if (conv == null) return;

    final result = KovacsEngine.playerPicked(
      conv: conv,
      picked: line,
      game: game,
      unlockedTopicIds: game.relay.unlockedTopicIds,
    );

    // Write updated conversation to provider
    ref.read(kovacsConversationProvider.notifier).state = result.conversation;

    var updatedRelay = game.relay.copyWith(mood: result.newMood);

    if (result.newlyUnlockedTopicId != null) {
      final newUnlocked = Set<String>.from(game.relay.unlockedTopicIds)
        ..add(result.newlyUnlockedTopicId!);
      updatedRelay = updatedRelay.copyWith(unlockedTopicIds: newUnlocked);
    }

    if (result.conversation.isComplete) {
      updatedRelay = updatedRelay.copyWith(conversationDoneThisWeek: true);
    }

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(relay: updatedRelay),
    );
  }

  // ─── Sell ─────────────────────────────────────────────────────────────────

  void _doConfirmShipment(GameState game) {
    if (_saleQueue.isEmpty) {
      _showKovacsSnack(game, 'no_cargo');
      return;
    }
    if (!game.isShipWindowOpen) {
      _showMsg('"Next pickup is Week ${game.nextShipWindowWeek}. I don\'t make special trips."');
      return;
    }

    final config = GameConfigService.instance;
    final discount = game.relay.priceDiscount;

    int totalScrip = 0;
    double totalVolume = 0;
    final updatedInventory = Map<String, double>.from(game.siloInventory);
    double meatSold = 0;

    for (final entry in _saleQueue.entries) {
      final crop = config.getCrop(entry.key);
      if (crop == null) continue;
      final price = (crop.baseScrip * (1 + discount)).round();
      totalScrip += (price * entry.value).round();
      totalVolume += crop.volumeM3 * entry.value;

      if (entry.key == 'fauna_meat') {
        // Meat comes from resources, not silo
        meatSold = entry.value;
      } else {
        final remaining = (updatedInventory[entry.key] ?? 0) - entry.value;
        if (remaining <= 0) updatedInventory.remove(entry.key);
        else updatedInventory[entry.key] = remaining;
      }
    }

    // Include any pending contract bonuses in this shipment
    final contractBonus = game.pendingContractScrip;
    totalScrip += contractBonus;

    final sale = PendingSale(
      resourceId: 'shipment_${game.currentWeek}',
      amount: totalVolume,
      scripValue: totalScrip,
      weekQueued: game.currentWeek,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        siloInventory: updatedInventory,
        resources: meatSold > 0
            ? game.resources.copyWith(
            meat: (game.resources.meat - meatSold).clamp(0, double.infinity))
            : game.resources,
        pendingSales: [...game.pendingSales, sale],
        pendingContractScrip: 0, // cleared — now in the shipment
        shipmentsThisWindow: game.shipmentsThisWindow + 1,
        totalVolumeDeliveredM3: game.totalVolumeDeliveredM3 + totalVolume,
      ),
    );
    setState(() => _saleQueue.clear());

    _showMsg('"Cargo received. ${totalVolume.toStringAsFixed(1)}m³. Scrip transfers next cycle."');
  }

  void _doSellAll(GameState game) {
    setState(() {
      _saleQueue.clear();
      _saleQueue.addAll(Map.from(game.siloInventory));
      if (game.resources.meat > 0) {
        _saleQueue['fauna_meat'] = game.resources.meat;
      }
    });
  }

  // ── Scrap Dealer ────────────────────────────────────────────────────────
  // A separate buyer from Kovacs/the Space Colony — pays cash on the spot
  // for raw metals/chemicals/components, bulk only, at a deliberately bad
  // rate. No shipping delay, no contract paperwork, just a flat dump.
  void _doScrapSell(GameState game, String resourceKey) {
    final config = GameConfigService.instance;
    final bulk = config.scrapDealerBulkAmount;
    final price = config.scrapDealerPrice(resourceKey);

    final have = switch (resourceKey) {
      'metals' => game.resources.metals,
      'chemicals' => game.resources.chemicals,
      'components' => game.resources.components,
      _ => 0.0,
    };
    if (have < bulk) return;

    final updatedResources = switch (resourceKey) {
      'metals' => game.resources.copyWith(
          metals: game.resources.metals - bulk,
          starScrip: game.resources.starScrip + price),
      'chemicals' => game.resources.copyWith(
          chemicals: game.resources.chemicals - bulk,
          starScrip: game.resources.starScrip + price),
      'components' => game.resources.copyWith(
          components: game.resources.components - bulk,
          starScrip: game.resources.starScrip + price),
      _ => game.resources,
    };

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(resources: updatedResources),
    );
    _showMsg('Scrap hauler weighs the load, pays cash, and rolls out. +$price 🎫');
  }

  void _doBuy(String itemId, int quantity, int costPerUnit, GameState game) {
    final totalCost = costPerUnit * quantity;
    if (game.resources.starScrip < totalCost) {
      _showMsg('"Insufficient Star-Scrip. Don\'t waste my time."');
      return;
    }

    // Charge scrip now; goods arrive next week as a pending delivery.
    final r = game.resources.copyWith(starScrip: game.resources.starScrip - totalCost);

    final resourceKey = switch (itemId) {
      'seeds_tier1' => 'seeds',
      'seeds_tier2' => 'seeds',
      'glass' => 'glass',
      'chemicals' => 'chemicals',
      'ore' => 'ore',
      'components' => 'components',
      _ => 'seeds',
    };
    final amount = quantity.toDouble();

    final delivery = PendingDelivery(
      resourceKey: resourceKey,
      amount: amount,
      arrivalWeek: game.currentWeek + 1,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        resources: r,
        pendingDeliveries: [...game.pendingDeliveries, delivery],
      ),
    );
    _showMsg('"Order placed. Arrives Week ${game.currentWeek + 1}."');
  }

  void _doAcceptContract(Contract contract, GameState game) {
    if (game.activeContracts.length >= 3) {
      _showMsg('"You already have 3 active contracts."');
      return;
    }
    final updated = contract.copyWith(status: ContractStatus.active);
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(activeContracts: [...game.activeContracts, updated]),
    );
    _showMsg('"Contract accepted. Get me ${contract.requiredAmount} units. Bonus on delivery."');
  }

  void _doSubmitToContract(String contractId, double amount, GameState game) {
    final idx = game.activeContracts.indexWhere((c) => c.id == contractId);
    if (idx < 0) return;
    final contract = game.activeContracts[idx];
    final inSilo = game.siloInventory[contract.cropId] ?? 0;
    final submitAmt = amount.clamp(0, inSilo)
        .clamp(0, (contract.requiredAmount - contract.currentAmount).toDouble());
    if (submitAmt <= 0) { _showMsg('"Nothing to submit."'); return; }

    final newCurrent = contract.currentAmount + submitAmt.round();
    final updatedContract = contract.copyWith(currentAmount: newCurrent);
    final updatedInv = Map<String, double>.from(game.siloInventory);
    final remaining = inSilo - submitAmt;
    if (remaining <= 0) updatedInv.remove(contract.cropId);
    else updatedInv[contract.cropId] = remaining;

    var active = List<Contract>.from(game.activeContracts);
    var completed = List<Contract>.from(game.completedContracts);
    int rewardScrip = 0;

    // Crops leave silo now, queued as pending shipment paid at next window
    final config = GameConfigService.instance;
    final crop = config.getCrop(contract.cropId);
    final volumeM3 = (crop?.volumeM3 ?? 1.0) * submitAmt;

    if (newCurrent >= contract.requiredAmount) {
      completed.add(updatedContract.copyWith(status: ContractStatus.completed));
      active.removeAt(idx);
      rewardScrip = contract.rewardScrip;
      _showMsg(
        '"Contract fulfilled. ${submitAmt.toInt()} units staged for pickup.'
            ' Kovacs collects Week ${game.nextShipWindowWeek}.'
            ' Payment on inspection."',
      );
    } else {
      active[idx] = updatedContract;
      _showMsg('"Logged. $newCurrent/${contract.requiredAmount}. Keep going."');
    }

    // The reward (if this submission completes the contract) rides along
    // with this exact shipment, so the week-end log and dashboard can show
    // it as one connected line instead of a separate, disconnected bonus.
    final sale = PendingSale(
      resourceId: 'contract_${contract.id}_${game.currentWeek}',
      amount: volumeM3,
      scripValue: rewardScrip,
      weekQueued: game.currentWeek,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        activeContracts: active,
        completedContracts: completed,
        siloInventory: updatedInv,
        pendingSales: [...game.pendingSales, sale],
        totalVolumeDeliveredM3: game.totalVolumeDeliveredM3 + volumeM3,
      ),
    );
  }

  void _showKovacsSnack(GameState game, String key) {
    final lines = GameConfigService.instance.getDialogueLines(key);
    final msg = lines.isNotEmpty ? lines[Random().nextInt(lines.length)] : 'Nothing to ship.';
    _showMsg('"$msg"');
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text(msg, style: MFTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: MFColors.surfaceElevated,
      ),
    );
  }
}

// ─── Kovacs Header ────────────────────────────────────────────────────────────

class _KovacsHeader extends StatelessWidget {
  final GameState game;
  const _KovacsHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final mood = game.relay.mood;
    final moodLabel = game.relay.moodLabel;
    final moodColor = _moodColor(mood);
    final discount = game.relay.priceDiscount;
    final discountText = discount >= 0
        ? '+${(discount * 100).toStringAsFixed(0)}% prices'
        : '${(discount * 100).toStringAsFixed(0)}% prices';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: moodColor.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                mood >= 85 ? '😊' : mood >= 65 ? '🙂' : mood >= 40 ? '😐' : mood >= 20 ? '😒' : '😤',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Specialist Kovacs', style: MFTextStyles.labelLarge),
                Text('Relay MF-7  ·  $moodLabel',
                    style: MFTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: mood / 100,
                  backgroundColor: MFColors.borderSubtle,
                  valueColor: AlwaysStoppedAnimation(moodColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 3),
              Text(discountText,
                  style: MFTextStyles.bodySmall.copyWith(
                    color: discount >= 0 ? MFColors.neonGreen : MFColors.neonPink,
                    fontSize: 9,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Color _moodColor(int mood) {
    if (mood >= 85) return MFColors.neonGreen;
    if (mood >= 65) return MFColors.statusOptimal;
    if (mood >= 40) return MFColors.neonYellow;
    if (mood >= 20) return MFColors.neonOrange;
    return MFColors.neonPink;
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────

class _RelayTabBar extends StatelessWidget {
  final RelayTab currentTab;
  final bool tabsUnlocked;
  final ValueChanged<RelayTab> onTabSelected;

  const _RelayTabBar({
    required this.currentTab,
    required this.tabsUnlocked,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (RelayTab.comms, '📡', 'COMMS', true),
      (RelayTab.sell, '📦', 'SELL', tabsUnlocked),
      (RelayTab.buy, '🛒', 'BUY', tabsUnlocked),
      (RelayTab.contracts, '📋', 'CONTRACTS', tabsUnlocked),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final (t, emoji, label, enabled) = tab;
          final isSelected = currentTab == t;
          return Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onTabSelected(t) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? MFColors.neonCyan : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(emoji,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled ? null : Colors.white24,
                        )),
                    const SizedBox(height: 2),
                    Text(label,
                        style: MFTextStyles.bodySmall.copyWith(
                          fontSize: 9,
                          color: !enabled
                              ? MFColors.borderDefault
                              : isSelected
                              ? MFColors.neonCyan
                              : MFColors.textMuted,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Conversation Tab ─────────────────────────────────────────────────────────

class _ConversationTab extends StatelessWidget {
  final GameState game;
  final KovacsConversation? conversation;
  final ValueChanged<PlayerLine> onPlayerPicked;

  const _ConversationTab({
    required this.game,
    required this.conversation,
    required this.onPlayerPicked,
  });

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return const Center(
        child: CircularProgressIndicator(color: MFColors.neonCyan, strokeWidth: 2),
      );
    }

    final conv = conversation!;

    return Column(
      children: [
        // ── Ship window status ────────────────────────────────────────────
        _ShipWindowStatus(game: game),

        // ── Conversation history ──────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: conv.history.length,
            itemBuilder: (_, i) {
              final bubble = conv.history[i];
              return _ConversationBubbleWidget(bubble: bubble);
            },
          ),
        ),

        // ── Player options or "done" state ────────────────────────────────
        if (conv.isComplete)
          _ConvComplete(game: game)
        else if (conv.isPlayerTurn)
          _PlayerOptions(
            options: conv.currentOptions,
            onPicked: onPlayerPicked,
          ),
      ],
    );
  }
}

class _ConversationBubbleWidget extends StatelessWidget {
  final ConversationBubble bubble;
  const _ConversationBubbleWidget({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final isKovacs = bubble.side == SpeakerSide.kovacs;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
        isKovacs ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Stage direction (Kovacs only)
          if (bubble.reactionNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4),
              child: Text(
                bubble.reactionNote!,
                style: MFTextStyles.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: MFColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isKovacs
                  ? MFColors.surfaceElevated
                  : bubble.isSelected
                  ? MFColors.neonCyan.withValues(alpha: 0.15)
                  : MFColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isKovacs ? 2 : 12),
                bottomRight: Radius.circular(isKovacs ? 12 : 2),
              ),
              border: Border.all(
                color: isKovacs
                    ? MFColors.borderDefault
                    : bubble.isSelected
                    ? MFColors.neonCyan.withValues(alpha: 0.5)
                    : MFColors.borderSubtle,
              ),
            ),
            child: Text(
              bubble.text,
              style: MFTextStyles.bodyMedium.copyWith(
                color: isKovacs ? MFColors.textPrimary : MFColors.neonCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerOptions extends StatelessWidget {
  final List<PlayerLine> options;
  final ValueChanged<PlayerLine> onPicked;

  const _PlayerOptions({required this.options, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onPicked(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: MFColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MFColors.borderDefault),
                ),
                child: Text(option.label, style: MFTextStyles.bodyLarge),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ConvComplete extends StatelessWidget {
  final GameState game;
  const _ConvComplete({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MFColors.borderSubtle)),
        color: MFColors.surfaceElevated,
      ),
      child: Text(
        '✅ Line clear. Sell, Buy, and Contracts are open.',
        style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Ship Window Status ───────────────────────────────────────────────────────

class _ShipWindowStatus extends StatelessWidget {
  final GameState game;
  const _ShipWindowStatus({required this.game});

  @override
  Widget build(BuildContext context) {
    final isOpen = game.isShipWindowOpen;
    final color = isOpen ? MFColors.neonGreen : MFColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isOpen ? MFColors.neonGreen.withValues(alpha: 0.05) : MFColors.surface,
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Text(isOpen ? '🚀' : '⏳', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOpen
                  ? 'Ship window open'
                  : 'Next pickup: Week ${game.nextShipWindowWeek} (${game.weeksToNextShipWindow} weeks)',
              style: MFTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sell Tab ─────────────────────────────────────────────────────────────────

class _SellTab extends StatelessWidget {
  final GameState game;
  final Map<String, double> saleQueue;
  final Function(String, double) onQueueChanged;
  final Function(GameState) onConfirmShipment;
  final Function(GameState) onSellAll;
  final Function(GameState, String) onScrapSell;

  const _SellTab({
    required this.game,
    required this.saleQueue,
    required this.onQueueChanged,
    required this.onConfirmShipment,
    required this.onSellAll,
    required this.onScrapSell,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final discount = game.relay.priceDiscount;

    int totalScrip = 0;
    double totalVolume = 0;
    for (final entry in saleQueue.entries) {
      final crop = config.getCrop(entry.key);
      if (crop == null) continue;
      final price = (crop.baseScrip * (1 + discount)).round();
      totalScrip += (price * entry.value).round();
      totalVolume += crop.volumeM3 * entry.value;
    }

    final hasMeat = game.resources.meat > 0;
    final meatCrop = config.getCrop('fauna_meat');
    final meatPrice = meatCrop != null
        ? (meatCrop.baseScrip * (1 + discount)).round()
        : 75;

    return Column(
      children: [
        // Contract sell items pinned at top
        ..._contractSellItems(context, game, config),

        Expanded(
          child: (game.siloInventory.isEmpty && !hasMeat)
              ? _EmptySiloMessage()
              : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── Silo inventory ──────────────────────────────────
              if (game.siloInventory.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text('SILO INVENTORY',
                          style: MFTextStyles.bodySmall.copyWith(
                              color: MFColors.textMuted, letterSpacing: 2)),
                    ),
                    GestureDetector(
                      onTap: () => onSellAll(game),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: MFColors.neonCyan.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('SELL ALL',
                            style: MFTextStyles.bodySmall.copyWith(
                                color: MFColors.neonCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...game.siloInventory.entries.map((entry) {
                  final crop = config.getCrop(entry.key);
                  if (crop == null) return const SizedBox();
                  final price = (crop.baseScrip * (1 + discount)).round();
                  final queued = saleQueue[entry.key] ?? 0;
                  return _SellItem(
                    crop: crop,
                    amount: entry.value,
                    pricePerUnit: price,
                    queuedAmount: queued,
                    onQueue: () => onQueueChanged(entry.key, entry.value),
                    onQueueHalf: () => onQueueChanged(entry.key, entry.value / 2),
                    onDequeue: () => onQueueChanged(entry.key, 0),
                  );
                }),
              ],

              // ── Fauna drops ─────────────────────────────────────
              if (hasMeat && meatCrop != null) ...[
                const SizedBox(height: 12),
                Text('FAUNA DROPS',
                    style: MFTextStyles.bodySmall.copyWith(
                        color: MFColors.textMuted, letterSpacing: 2)),
                const SizedBox(height: 8),
                _SellItem(
                  crop: meatCrop,
                  amount: game.resources.meat,
                  pricePerUnit: meatPrice,
                  queuedAmount: saleQueue['fauna_meat'] ?? 0,
                  onQueue: () =>
                      onQueueChanged('fauna_meat', game.resources.meat),
                  onQueueHalf: () =>
                      onQueueChanged('fauna_meat', game.resources.meat / 2),
                  onDequeue: () => onQueueChanged('fauna_meat', 0),
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _ScrapDealerSection(game: game, onScrapSell: onScrapSell),
        ),

        if (saleQueue.isNotEmpty)
          _ShipmentSummary(
            totalScrip: totalScrip,
            totalVolume: totalVolume,
            isWindowOpen: game.isShipWindowOpen,
            onConfirm: () => onConfirmShipment(game),
          ),
      ],
    );
  }

  List<Widget> _contractSellItems(
      BuildContext context, GameState game, GameConfigService config) {
    final active = game.activeContracts
        .where((c) => (game.siloInventory[c.cropId] ?? 0) > 0)
        .toList();
    if (active.isEmpty) return [];

    return [
      Container(
        padding: const EdgeInsets.all(10),
        color: MFColors.neonGold.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 ACTIVE CONTRACTS',
                style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonGold, letterSpacing: 2, fontSize: 10)),
            const SizedBox(height: 6),
            ...active.map((c) {
              final crop = config.getCrop(c.cropId);
              final inSilo = game.siloInventory[c.cropId] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MFColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: MFColors.neonGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Text(crop?.emoji ?? '?',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: MFTextStyles.labelLarge),
                          Text(
                            '${c.currentAmount}/${c.requiredAmount}  ·  ${inSilo.toInt()} in silo',
                            style: MFTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text('+${c.rewardScrip} 🎫',
                        style: MFTextStyles.bodySmall
                            .copyWith(color: MFColors.neonGold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }
}

// ─── Scrap Dealer ───────────────────────────────────────────────────────────
// A separate, bulk-only buyer from Kovacs/the Space Colony — pays cash on
// the spot for raw metals/chemicals/components at a deliberately bad rate.

class _ScrapDealerSection extends StatelessWidget {
  final GameState game;
  final Function(GameState, String) onScrapSell;

  const _ScrapDealerSection({required this.game, required this.onScrapSell});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final bulk = config.scrapDealerBulkAmount;

    final rows = [
      ('metals', '🔩', 'Metals', game.resources.metals),
      ('chemicals', '⚗️', 'Chemicals', game.resources.chemicals),
      ('components', '⚙️', 'Components', game.resources.components),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCRAP DEALER',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(
            'Not Kovacs, not the Colony — a separate scrap contact. '
                'Bulk only, by the truckload, at a junkyard rate.',
            style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final (key, emoji, label, have) = row;
            final price = config.scrapDealerPrice(key);
            final canSell = have >= bulk;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: MFTextStyles.bodyLarge),
                        Text(
                          '${have.toInt()} on hand  ·  $bulk → $price 🎫',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: canSell ? MFColors.textSecondary : MFColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: canSell ? () => onScrapSell(game, key) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: canSell
                            ? MFColors.neonOrange.withValues(alpha: 0.12)
                            : MFColors.borderSubtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: canSell
                              ? MFColors.neonOrange.withValues(alpha: 0.5)
                              : MFColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'SELL $bulk',
                        style: MFTextStyles.bodySmall.copyWith(
                          color: canSell ? MFColors.neonOrange : MFColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SellItem extends StatelessWidget {
  final CropConfig crop;
  final double amount;
  final int pricePerUnit;
  final double queuedAmount;
  final VoidCallback onQueue;
  final VoidCallback onQueueHalf;
  final VoidCallback onDequeue;

  const _SellItem({
    required this.crop,
    required this.amount,
    required this.pricePerUnit,
    required this.queuedAmount,
    required this.onQueue,
    required this.onQueueHalf,
    required this.onDequeue,
  });

  @override
  Widget build(BuildContext context) {
    final isQueued = queuedAmount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isQueued
            ? MFColors.neonGreen.withValues(alpha: 0.05)
            : MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isQueued
              ? MFColors.neonGreen.withValues(alpha: 0.4)
              : MFColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Text(crop.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.name, style: MFTextStyles.bodyLarge),
                Text(
                  '${amount.toInt()} units  ·  '
                      '${crop.volumeM3}m³ each  ·  '
                      '$pricePerUnit 🎫',
                  style: MFTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (isQueued)
            GestureDetector(
              onTap: onDequeue,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MFColors.neonPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: MFColors.neonPink.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'REMOVE',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonPink,
                    fontSize: 10,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: onQueueHalf,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: MFColors.neonCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: MFColors.neonCyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '1/2',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: MFColors.neonCyan,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onQueue,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: MFColors.neonGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: MFColors.neonGreen.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'SELL ALL',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: MFColors.neonGreen,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ShipmentSummary extends StatelessWidget {
  final int totalScrip;
  final double totalVolume;
  final bool isWindowOpen;
  final VoidCallback onConfirm;

  const _ShipmentSummary({
    required this.totalScrip,
    required this.totalVolume,
    required this.isWindowOpen,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MFColors.borderSubtle)),
        color: MFColors.surface,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${totalVolume.toStringAsFixed(1)}m³ cargo',
                  style: MFTextStyles.bodyMedium),
              Text('+$totalScrip 🎫 next week',
                  style: MFTextStyles.labelLarge
                      .copyWith(color: MFColors.starScrip)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isWindowOpen ? MFColors.neonGreen : MFColors.textMuted,
                foregroundColor: MFColors.background,
              ),
              onPressed: isWindowOpen ? onConfirm : null,
              child: Text(
                isWindowOpen ? '🚀 CONFIRM SHIPMENT' : 'WINDOW CLOSED',
                style: MFTextStyles.labelLarge
                    .copyWith(color: MFColors.background),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySiloMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📦', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Silo is empty.', style: MFTextStyles.headlineMedium),
            SizedBox(height: 8),
            Text(
              'Harvest crops in your domes,\nthen come back to ship them.',
              style: MFTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Buy Tab ──────────────────────────────────────────────────────────────────

class _BuyTab extends StatelessWidget {
  final GameState game;
  final Function(String, int, int, GameState) onBuy;

  const _BuyTab({required this.game, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final mood = game.relay.mood;
    final markup = mood < 40 ? 1.3 : mood < 65 ? 1.0 : 0.9;

    // (id, emoji, name, desc, pricePerUnit, batchSize)
    final items = [
      ('seeds_tier1', '🌾', 'Tier 1 Seeds (×8)', 'Basic crop seeds', 1, 8),
      ('seeds_tier2', '🌿', 'Tier 2 Seeds (×8)', 'Advanced crop seeds', 4, 8),
      ('glass', '🪟', 'Glass (×10)', 'Refined glass panels', 6, 10),
      ('chemicals', '⚗️', 'Chemicals (×5)', 'Industrial reagents', 8, 5),
      ('ore', '🪨', 'Raw Ore (×5)', 'Unprocessed mineral ore', 12, 5),
      ('components', '⚙️', 'Components (×2)', 'Tech circuitry', 45, 2),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Text(
            mood < 40
                ? '"Stock is limited. Prices reflect my current mood."'
                : '"Weekly supply drop available. Prices are what they are."',
            style:
            MFTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        ...items.map((item) {
          final (id, emoji, name, desc, basePrice, batchSize) = item;
          final price1 = (basePrice * batchSize * markup).round();
          final price5 = (basePrice * batchSize * 5 * markup).round();
          final price10 = (basePrice * batchSize * 10 * markup).round();
          final canAfford1 = game.resources.starScrip >= price1;
          final canAfford5 = game.resources.starScrip >= price5;
          final canAfford10 = game.resources.starScrip >= price10;

          final showX5 = game.currentWeek >= 20;
          final showX10 = game.currentWeek >= 40;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: MFTextStyles.bodyLarge),
                          Text(desc, style: MFTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Buy x1 batch — medium teal
                    _BuyButton(
                      label: 'BUY',
                      price: price1,
                      canAfford: canAfford1,
                      color: const Color(0xFF00838F), // medium teal
                      onTap: () => onBuy(id, batchSize,
                          (price1 / batchSize).ceil(), game),
                    ),
                    if (showX5) ...[
                      const SizedBox(width: 6),
                      _BuyButton(
                        label: '×5',
                        price: price5,
                        canAfford: canAfford5,
                        color: const Color(0xFF0097A7), // medium-bright teal
                        onTap: () => onBuy(id, batchSize * 5,
                            (price5 / (batchSize * 5)).ceil(), game),
                      ),
                    ],
                    if (showX10) ...[
                      const SizedBox(width: 6),
                      _BuyButton(
                        label: '×10',
                        price: price10,
                        canAfford: canAfford10,
                        color: const Color(0xFF00BCD4), // bright teal
                        onTap: () => onBuy(id, batchSize * 10,
                            (price10 / (batchSize * 10)).ceil(), game),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Buy Button ───────────────────────────────────────────────────────────────

class _BuyButton extends StatelessWidget {
  final String label;
  final int price;
  final bool canAfford;
  final Color color;
  final VoidCallback onTap;

  const _BuyButton({
    required this.label,
    required this.price,
    required this.canAfford,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: canAfford ? color.withValues(alpha: 0.15) : MFColors.borderSubtle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: canAfford ? color.withValues(alpha: 0.6) : MFColors.borderSubtle,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MFTextStyles.bodySmall.copyWith(
                color: canAfford ? color : MFColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            Text(
              '$price 🎫',
              style: MFTextStyles.bodySmall.copyWith(
                color: canAfford ? color : MFColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Contracts Tab ────────────────────────────────────────────────────────────

class _ContractsTab extends StatelessWidget {
  final GameState game;
  final Function(Contract, GameState) onAcceptContract;
  final Function(String, double, GameState) onSubmitToContract;

  const _ContractsTab({
    required this.game,
    required this.onAcceptContract,
    required this.onSubmitToContract,
  });

  @override
  Widget build(BuildContext context) {
    final available = GameFactory.generateContractOptions(
      domes: game.domes,
      currentWeek: game.currentWeek,
      moodDiscount: game.relay.priceDiscount,
    ).take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (game.activeContracts.isNotEmpty) ...[
          Text('ACTIVE',
              style: MFTextStyles.bodySmall
                  .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...game.activeContracts.map((c) => _ContractCard(
            contract: c,
            game: game,
            isActive: true,
            onSubmit: () {
              final inSilo = game.siloInventory[c.cropId] ?? 0;
              final remaining = (c.requiredAmount - c.currentAmount).toDouble();
              final amt = inSilo.clamp(0, remaining).toDouble();
              onSubmitToContract(c.id, amt, game);
            },
          )),
          const SizedBox(height: 16),
        ],
        Text('AVAILABLE',
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        if (available.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.borderSubtle),
            ),
            child: Text(
              '"No contracts available right now." — Kovacs',
              style: MFTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
            ),
          )
        else
          ...available.map((c) => _ContractCard(
            contract: c,
            game: game,
            isActive: false,
            onAccept: () => onAcceptContract(c, game),
          )),
        if (game.completedContracts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('COMPLETED (${game.completedContracts.length})',
              style: MFTextStyles.bodySmall
                  .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...game.completedContracts.take(3).map((c) => _ContractCard(
            contract: c,
            game: game,
            isActive: false,
          )),
        ],
      ],
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Contract contract;
  final GameState game;
  final bool isActive;
  final VoidCallback? onAccept;
  final VoidCallback? onSubmit;

  const _ContractCard({
    required this.contract,
    required this.game,
    required this.isActive,
    this.onAccept,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final crop = config.getCrop(contract.cropId);
    final isCompleted = contract.status == ContractStatus.completed;
    final inSilo = game.siloInventory[contract.cropId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted
              ? MFColors.neonGreen.withValues(alpha: 0.3)
              : isActive
              ? MFColors.neonGold.withValues(alpha: 0.4)
              : MFColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(crop?.emoji ?? '?', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(contract.title, style: MFTextStyles.labelLarge)),
              Text('+${contract.rewardScrip} 🎫',
                  style: MFTextStyles.bodySmall
                      .copyWith(color: MFColors.neonGold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(contract.description, style: MFTextStyles.bodySmall),
          if (isActive || isCompleted) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: contract.progress.clamp(0.0, 1.0),
              backgroundColor: MFColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? MFColors.neonGreen : MFColors.neonGold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${contract.currentAmount}/${contract.requiredAmount}m³',
                    style: MFTextStyles.bodySmall),
                if (isCompleted)
                  Text('✅ COMPLETE',
                      style: MFTextStyles.bodySmall
                          .copyWith(color: MFColors.neonGreen))
                else if (inSilo > 0)
                  Text('${inSilo.toInt()} in silo',
                      style: MFTextStyles.bodySmall
                          .copyWith(color: MFColors.neonCyan)),
              ],
            ),
          ],
          if (isActive && !isCompleted && onSubmit != null) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final remaining = contract.requiredAmount - contract.currentAmount;
              final submitAmt = inSilo.clamp(0, remaining.toDouble()).toInt();
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: submitAmt > 0 ? onSubmit : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: submitAmt > 0
                            ? MFColors.neonGold
                            : MFColors.borderSubtle),
                    foregroundColor: MFColors.neonGold,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    submitAmt > 0
                        ? 'SUBMIT $submitAmt FROM SILO'
                        : 'NOTHING IN SILO',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: submitAmt > 0 ? MFColors.neonGold : MFColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
          if (!isActive && !isCompleted && onAccept != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MFColors.neonCyan,
                  foregroundColor: MFColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text('ACCEPT CONTRACT',
                    style: MFTextStyles.labelLarge
                        .copyWith(color: MFColors.background)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}