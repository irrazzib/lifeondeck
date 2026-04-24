import 'package:flutter/foundation.dart';

import '../core/constants.dart';
// Note: game_record.dart imports this file. SideboardBookResult and SideboardDeckEditResult
// need GameRecord, so they are defined in game_record.dart to avoid circular imports.

@immutable
class SideboardCardEntry {
  const SideboardCardEntry({required this.name, required this.copies});

  final String name;
  final int copies;

  SideboardCardEntry copyWith({String? name, int? copies}) {
    return SideboardCardEntry(
      name: name ?? this.name,
      copies: copies ?? this.copies,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{'name': name, 'copies': copies};
  }

  factory SideboardCardEntry.fromJson(Map<String, dynamic> json) {
    final String rawName = (json['name'] as String?)?.trim() ?? '';
    final String name = rawName.isEmpty ? 'Card' : rawName;

    int copies = 1;
    final Object? rawCopies = json['copies'];
    if (rawCopies is int) {
      copies = rawCopies;
    } else if (rawCopies is String) {
      copies = int.tryParse(rawCopies) ?? 1;
    }
    copies = copies.clamp(1, 4);

    return SideboardCardEntry(name: name, copies: copies);
  }
}

@immutable
class SideboardMatchup {
  const SideboardMatchup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sideIn,
    required this.sideOut,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<SideboardCardEntry> sideIn;
  final List<SideboardCardEntry> sideOut;

  SideboardMatchup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<SideboardCardEntry>? sideIn,
    List<SideboardCardEntry>? sideOut,
  }) {
    return SideboardMatchup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sideIn: sideIn ?? this.sideIn,
      sideOut: sideOut ?? this.sideOut,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sideIn': sideIn
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
      'sideOut': sideOut
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  factory SideboardMatchup.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Matchup';
    final String rawCreatedAt = (json['createdAt'] as String?) ?? '';
    DateTime createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    if (rawCreatedAt.trim().isEmpty) {
      final int? createdAtFromId = int.tryParse(id);
      if (createdAtFromId != null) {
        createdAt = DateTime.fromMicrosecondsSinceEpoch(createdAtFromId);
      }
    }

    List<SideboardCardEntry> parseCardList(String key) {
      final Object? raw = json[key];
      if (raw is! List) {
        return const <SideboardCardEntry>[];
      }

      final List<SideboardCardEntry> parsed = <SideboardCardEntry>[];
      for (final Object? item in raw) {
        if (item is Map) {
          parsed.add(
            SideboardCardEntry.fromJson(Map<String, dynamic>.from(item)),
          );
          continue;
        }

        final String asText = item?.toString().trim() ?? '';
        if (asText.isEmpty) {
          continue;
        }
        parsed.add(SideboardCardEntry(name: asText, copies: 1));
      }
      return parsed.toList(growable: false);
    }

    return SideboardMatchup(
      id: id,
      name: name,
      createdAt: createdAt,
      sideIn: parseCardList('sideIn'),
      sideOut: parseCardList('sideOut'),
    );
  }
}

@immutable
class SideboardDeck {
  const SideboardDeck({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isFavorite,
    required this.userNotes,
    required this.matchups,
    this.format = '',
    this.tag = '',
    this.tcgKey = 'yugioh',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isFavorite;
  final String userNotes;
  final List<SideboardMatchup> matchups;
  final String format;
  final String tag;
  final String tcgKey;

  SideboardDeck copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isFavorite,
    String? userNotes,
    List<SideboardMatchup>? matchups,
    String? format,
    String? tag,
    String? tcgKey,
  }) {
    return SideboardDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      userNotes: userNotes ?? this.userNotes,
      matchups: matchups ?? this.matchups,
      format: format ?? this.format,
      tag: tag ?? this.tag,
      tcgKey: tcgKey ?? this.tcgKey,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'userNotes': userNotes,
      'matchups': matchups
          .map((SideboardMatchup matchup) => matchup.toJson())
          .toList(growable: false),
      'tag': tag,
      'format': format,
      'tcgKey': tcgKey,
    };
  }

  factory SideboardDeck.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Deck';
    final DateTime createdAt =
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now();
    final bool isFavorite = json['isFavorite'] == true;
    final String userNotes = (json['userNotes'] as String?) ?? '';
    final String tag = ((json['tag'] as String?) ?? '').trim();
    final String format = ((json['format'] as String?) ?? '').trim();
    final String tcgKey = normalizeTcgKey(json['tcgKey'] as String?);
    final Object? rawMatchups = json['matchups'];
    final List<SideboardMatchup> parsedMatchups = rawMatchups is List
        ? rawMatchups
              .whereType<Map>()
              .map(
                (Map item) =>
                    SideboardMatchup.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <SideboardMatchup>[];

    return SideboardDeck(
      id: id,
      name: name,
      createdAt: createdAt,
      isFavorite: isFavorite,
      userNotes: userNotes,
      matchups: parsedMatchups,
      format: format.isNotEmpty ? format : tag,
      tag: tag,
      tcgKey: tcgKey,
    );
  }
}

