import 'anime.dart';

abstract class AnimeRepository {
  Future<List<Anime>> getTrending();
  Future<List<Anime>> getTopRated({int page = 1});
  Future<List<Anime>> getCurrentSeason();
  Future<List<Anime>> getUpcomingSeason();
  Future<List<Anime>> searchAnime(
    String query, {
    int page = 1,
    List<int>? genres,
    String? status,
    String? orderBy,
    bool allowAdult = false,
  });
  Future<Anime> getAnimeDetail(int id);

  /// Aliran detail anime reaktif: memancarkan data offline/cache seketika (0 ms)
  /// agar halaman langsung terbuka tanpa buffering, lalu memancarkan pembaruan
  /// detail lengkap (karakter, trailer, lagu tema) saat selesai di latar belakang.
  Stream<Anime> watchAnimeDetail(int id);

  /// Ambil data dari cache memori jika sudah pernah dimuat.
  Anime? getCachedDetail(int id);

  /// Anime serupa (rekomendasi komunitas MAL). Boleh kosong.
  Future<List<Anime>> getRecommendations(int id);
}
