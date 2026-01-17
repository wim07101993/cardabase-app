import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/uri_extensions.dart';

class ApiSettings {
  const ApiSettings({
    required this.baseUrl,
  });

  final Uri baseUrl;
}

class CardabaseApi {
  const CardabaseApi({
    required this.settings,
    required this.accessTokenProvider,
  });

  final ApiSettings settings;
  final Future<String?> Function() accessTokenProvider;

  Future<void> checkConnection() async {
    final response = await http.get(
      settings.baseUrl.appendPathSegments(['healthz']),
    );

    if (response.statusCode >= 400) {
      throw HttpRequestException(response);
    }
  }

  Future<void> saveCard(String cardId, Map<String, dynamic> data) async {
    final accessToken = await accessTokenProvider();

    final response = await http.put(
      settings.baseUrl.appendPathSegments(['cards', cardId]),
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'bearer $accessToken',
      },
    );

    if (response.statusCode >= 400) {
      throw HttpRequestException(response);
    }
  }

  Future<Map<String, dynamic>> getCard(String cardId) async {
    final accessToken = await accessTokenProvider();

    final response = await http.get(
      settings.baseUrl.appendPathSegments(['cards', cardId]),
      headers: {
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'bearer $accessToken',
      },
    );

    if (response.statusCode >= 400) {
      throw HttpRequestException(response);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteCard(String cardId) async {
    final accessToken = await accessTokenProvider();

    final response = await http.delete(
      settings.baseUrl.appendPathSegments(['cards', cardId]),
      headers: {
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'bearer $accessToken',
      },
    );

    if (response.statusCode >= 400) {
      throw HttpRequestException(response);
    }
  }

  Future<List<Map<String, dynamic>>> getAllCards({
    DateTime? changesSince,
    DateTime? changesUntil,
  }) async {
    final accessToken = await accessTokenProvider();

    final response = await http.get(
      settings.baseUrl.appendPathSegments(['cards']),
      headers: {
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'bearer $accessToken',
      },
    );

    if (response.statusCode >= 400) {
      throw HttpRequestException(response);
    }

    return jsonDecode(response.body) as List<Map<String, dynamic>>;
  }
}

class HttpRequestException implements Exception {
  const HttpRequestException(this.response);

  final http.Response response;
}
