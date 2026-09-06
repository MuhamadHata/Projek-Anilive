// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  print('--- Anime Offline Database Fetcher & Converter ---');
  final dio = Dio();
  final urls = <String>[];
  // Resolve latest release tag
  try {
    final rel = await dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/manami-project/anime-offline-database/releases/latest',
    );
    final tag = rel.data?['tag_name'] as String?;
    if (tag != null) {
      urls.add('https://github.com/manami-project/anime-offline-database/releases/download/$tag/anime-offline-database-minified.json');
    }
  } catch (_) {}
  urls.add('https://github.com/manami-project/anime-offline-database/releases/download/2026-27/anime-offline-database-minified.json');

  String? dataStr;
  for (final url in urls) {
    print('Mengunduh dataset dari: $url ...');
    try {
      final res = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (res.statusCode == 200 && res.data != null) {
        dataStr = res.data;
        break;
      }
    } catch (_) {}
  }

  if (dataStr == null) {
    print('Gagal mengunduh dataset dari semua sumber.');
    return;
  }

  print('Parsing data...');
  try {
    final json = jsonDecode(dataStr) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];
    print('Total anime dalam dataset: ${data.length}');

    final compactList = <Map<String, dynamic>>[];
    for (final item in data) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final title = m['title'] as String? ?? '';
      final synonyms = (m['synonyms'] as List<dynamic>? ?? []).whereType<String>().toList();
      final picture = m['picture'] as String? ?? '';
      final type = m['type'] as String? ?? '';
      final episodes = (m['episodes'] as num?)?.toInt() ?? 1;
      final status = m['status'] as String? ?? '';
      final animeSeason = m['animeSeason'] as Map<String, dynamic>? ?? {};
      final year = (animeSeason['year'] as num?)?.toInt();
      final tags = (m['tags'] as List<dynamic>? ?? []).whereType<String>().take(5).toList();

      // Extract MAL id from sources if available
      int? malId;
      final sources = (m['sources'] as List<dynamic>? ?? []).whereType<String>();
      for (final s in sources) {
        if (s.contains('myanimelist.net/anime/')) {
          final idStr = s.split('myanimelist.net/anime/').last.split('/').first.split('?').first;
          malId = int.tryParse(idStr);
          break;
        }
      }

      compactList.add({
        'id': malId ?? compactList.length + 100000,
        'title': title,
        'synonyms': synonyms,
        'imageUrl': picture,
        'type': type,
        'episodes': episodes,
        'status': status,
        'year': year,
        'genres': tags,
      });
    }

    final outDir = Directory('assets/data');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final outFile = File('assets/data/anime_offline.json');
    print('Menyimpan ke ${outFile.path} (Total: ${compactList.length} anime)...');
    await outFile.writeAsString(jsonEncode(compactList));
    print('SELESAI! Database anime offline berhasil dibuat di assets/data/anime_offline.json');
  } catch (e) {
    print('Error: $e');
  }
}
