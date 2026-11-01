import 'dart:async';

import 'package:betting_sim/ui/proposal_card.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// What the player can do about an offer.
enum OfferChoice {
  /// Take it as offered.
  accept,

  /// Ask for a better price.
  haggle,

  /// Turn it down.
  reject,
}

/// One friend's offer as an avatar tile: the face, the stake, and -- once
/// dealt with -- what came of it.
///
/// The offer itself (message, terms and the three choices) is one tap away in
/// a sheet, so a whole week of offers fits a page instead of a long list.
class FriendTile extends StatelessWidget {
  /// Creates a tile for [terms] on [fixture].
  const new({
    required this.terms,
    required this.fixture,
    required this.outcome,
    required this.onChoose,
    super.key,
  });

  /// What was offered.
  final ProposalTerms terms;

  /// Which match, as text.
  final String fixture;

  /// What you already did about it, if anything.
  final String? outcome;

  /// Called with the choice made in the sheet.
  final ValueChanged<OfferChoice> onChoose;

  void _open(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Tokens.inkRaised1,
        builder: (sheet) {
          void choose(OfferChoice choice) {
            Navigator.of(sheet).pop();
            onChoose(choice);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: ProposalCard(
                terms: terms,
                fixture: fixture,
                outcome: outcome,
                onAccept: () => choose(OfferChoice.accept),
                onHaggle: () => choose(OfferChoice.haggle),
                onReject: () => choose(OfferChoice.reject),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = terms.proposal;
    final decided = outcome != null;
    final small = text.bodySmall?.copyWith(fontSize: 11);
    return Semantics(
      button: true,
      label: '${p.name} on $fixture',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(Tokens.radius),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Tokens.inkRaised2,
                      border: Border.all(
                        color: decided ? Tokens.lineDark : Tokens.accent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p.name.characters.first.toUpperCase(),
                        style: text.headlineSmall?.copyWith(
                          color: decided
                              ? Tokens.mutedOnDark
                              : Tokens.textOnDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: decided
                  ? Text(
                      outcome!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(color: Tokens.accent),
                    )
                  : Column(
                      children: <Widget>[
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small?.copyWith(color: Tokens.textOnDark),
                        ),
                        Text(p.stake.toStringAsFixed(0), style: small),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
