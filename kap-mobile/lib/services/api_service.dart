import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_item.dart';

class ApiService {
  // Production sunucu adresi
  static const String baseUrl = 'http://91.132.49.137:5296/api';

  Future<List<NewsItem>> getLatestNews({int count = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news/latest?count=$count'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => NewsItem.fromJson(json)).toList();
      } else {
        throw Exception('Haberler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<List<NewsItem>> getNewsByTicker(String ticker, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news/ticker/$ticker?page=$page&pageSize=$pageSize'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => NewsItem.fromJson(json)).toList();
      } else {
        throw Exception('Haberler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<List<NewsItem>> getTodayNews() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news/today'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => NewsItem.fromJson(json)).toList();
      } else {
        throw Exception('Haberler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<List<NewsItem>> getAllNews({int page = 1, int pageSize = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news?page=$page&pageSize=$pageSize'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => NewsItem.fromJson(json)).toList();
      } else {
        throw Exception('Haberler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }
  Future<List<dynamic>> getChartData(String ticker, String timeframe) async {
    try {
      final url = '$baseUrl/Chart/ticker?symbol=$ticker&time=$timeframe';
      print('═══════════════════════════════════════════════════════════');
      print('📊 API ÇAĞRISI');
      print('═══════════════════════════════════════════════════════════');
      print('🔗 URL: $url');
      
      final response = await http.get(Uri.parse(url));

      print('📡 HTTP Status: ${response.statusCode}');
      print('📋 Headers: ${response.headers}');
      print('───────────────────────────────────────────────────────────');
      print('📦 HAM VERİ (RAW JSON):');
      print('───────────────────────────────────────────────────────────');
      print(response.body);
      print('═══════════════════════════════════════════════════════════\n');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('❌ API Hata: ${response.statusCode} - ${response.body}');
        throw Exception('Grafik verisi yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception: $e');
      throw Exception('Bağlantı hatası: $e');
    }
  }
}
