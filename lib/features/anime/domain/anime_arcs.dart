/// Arc (saga) untuk anime panjang, dipetakan ke nomor episode.
class AnimeArc {
  final String name;
  final int startEpisode;
  final int endEpisode;

  const AnimeArc(this.name, this.startEpisode, this.endEpisode);

  bool contains(int episode) =>
      episode >= startEpisode && episode <= endEpisode;
}

class AnimeArcDb {
  /// Urutan pengecekan penting: key yang lebih spesifik harus di atas
  /// (misal "naruto shippuden" sebelum "naruto").
  static const List<MapEntry<String, List<AnimeArc>>> _arcData = [
    MapEntry('one piece', _onePiece),
    MapEntry('bleach', _bleach),
    MapEntry('naruto shippuden', _narutoShippuden),
    MapEntry('naruto shippuuden', _narutoShippuden),
    MapEntry('naruto', _naruto),
  ];

  /// Cari daftar arc berdasarkan judul anime. Null jika tidak ada data.
  static List<AnimeArc>? find(String title) {
    final t = title.toLowerCase().trim();
    for (final entry in _arcData) {
      if (t.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static AnimeArc? arcForEpisode(List<AnimeArc> arcs, int episode) {
    for (final a in arcs) {
      if (a.contains(episode)) return a;
    }
    return null;
  }
}

const List<AnimeArc> _onePiece = [
  AnimeArc('East Blue', 1, 61),
  AnimeArc('Arabasta', 62, 135),
  AnimeArc('Sky Island (Skypiea)', 136, 206),
  AnimeArc('Water 7 & Enies Lobby', 207, 325),
  AnimeArc('Thriller Bark', 326, 384),
  AnimeArc('Marineford (Summit War)', 385, 516),
  AnimeArc('Fish-Man Island', 517, 574),
  AnimeArc('Dressrosa', 575, 746),
  AnimeArc('Whole Cake Island', 747, 889),
  AnimeArc('Wano Country', 890, 1085),
  AnimeArc('Egghead (Final Saga)', 1086, 1121),
];

const List<AnimeArc> _bleach = [
  AnimeArc('Agent of the Shinigami', 1, 20),
  AnimeArc('Soul Society', 21, 63),
  AnimeArc('Bount (Filler)', 64, 109),
  AnimeArc('Arrancar', 110, 167),
  AnimeArc('Hueco Mundo', 168, 205),
  AnimeArc('Past Arc', 206, 212),
  AnimeArc('Fake Karakura Town', 213, 265),
  AnimeArc('Lost Agent / Fullbring', 266, 316),
  AnimeArc('Gotei 13 Invading Army (Filler)', 317, 366),
];

const List<AnimeArc> _naruto = [
  AnimeArc('Land of Waves', 1, 19),
  AnimeArc('Chunin Exam', 20, 67),
  AnimeArc('Konoha Crush', 68, 80),
  AnimeArc('Rice Fields Investigation', 81, 100),
  AnimeArc('Sasuke Recovery Mission', 101, 135),
  AnimeArc('Filler Arcs', 136, 220),
];

const List<AnimeArc> _narutoShippuden = [
  AnimeArc('Kazekage Rescue', 1, 32),
  AnimeArc('Tenchi Bridge Reconnaissance', 33, 53),
  AnimeArc('Twelve Guardian Ninja (Filler)', 54, 71),
  AnimeArc('Akatsuki Suppression (Hidan-Kakuzu)', 72, 88),
  AnimeArc('Three-Tails Appearance (Filler)', 89, 112),
  AnimeArc('Itachi Pursuit', 113, 143),
  AnimeArc('Six-Tails Unleashed (Filler)', 144, 151),
  AnimeArc("Pain's Assault", 152, 175),
  AnimeArc('Konoha History (Filler)', 176, 196),
  AnimeArc('Five Kage Summit', 197, 221),
  AnimeArc('Paradise Life on a Boat (Filler)', 222, 242),
  AnimeArc('Confining Jinchuriki', 243, 275),
  AnimeArc('Fourth Shinobi World War: Countdown', 276, 289),
  AnimeArc('Fourth Shinobi World War: Climax', 290, 375),
  AnimeArc('Birth of Ten-Tails Jinchuriki', 376, 455),
  AnimeArc("Kaguya's Will", 456, 474),
  AnimeArc("Naruto & Hinata's Wedding", 494, 500),
];
