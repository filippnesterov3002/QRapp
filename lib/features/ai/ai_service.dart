import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Описание функции, которую модель может вызвать через Responses API.
class AiToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final bool strict;

  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.strict = true,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'name': name,
        'description': description,
        'strict': strict,
        'parameters': parameters,
      };
}

class AiFunctionCall {
  final String name;
  final String callId;
  final Map<String, dynamic> arguments;

  const AiFunctionCall({
    required this.name,
    required this.callId,
    required this.arguments,
  });
}

class AiToolOutput {
  final String callId;
  final String output;

  const AiToolOutput({
    required this.callId,
    required this.output,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function_call_output',
        'call_id': callId,
        'output': output,
      };
}

class AiResponse {
  final String? id;
  final String text;
  final List<AiFunctionCall> functionCalls;
  final Map<String, dynamic> rawJson;

  const AiResponse({
    required this.id,
    required this.text,
    required this.functionCalls,
    required this.rawJson,
  });

  bool get hasFunctionCalls => functionCalls.isNotEmpty;
}

class AiServiceException implements Exception {
  final String message;
  final Object? cause;

  const AiServiceException(this.message, {this.cause});

  @override
  String toString() => 'AiServiceException: $message';
}

/// Минимальная HTTP-обертка над OpenAI Responses API.
///
/// API-ключ читается из dart-define:
/// --dart-define=OPENAI_API_KEY=...
class AiService {
  static const _defaultBaseUrl = 'https://api.openai.com/v1';
  static const _defaultModel = 'gpt-5.5';

  final String apiKey;
  final String baseUrl;
  final String model;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  AiService({
    String? apiKey,
    String? baseUrl,
    String? model,
    Duration? timeout,
    http.Client? client,
  })  : apiKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY'),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'OPENAI_API_BASE_URL',
              defaultValue: _defaultBaseUrl,
            ),
        model = model ??
            const String.fromEnvironment(
              'OPENAI_MODEL',
              defaultValue: _defaultModel,
            ),
        timeout = timeout ?? const Duration(seconds: 45),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  Future<AiResponse> sendUserMessage({
    required String message,
    required String instructions,
    required List<AiToolDefinition> tools,
    String? previousResponseId,
  }) {
    return _createResponse(
      instructions: instructions,
      tools: tools,
      previousResponseId: previousResponseId,
      input: [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': message},
          ],
        },
      ],
    );
  }

  Future<AiResponse> submitToolOutputs({
    required List<AiToolOutput> outputs,
    required String instructions,
    required List<AiToolDefinition> tools,
    required String previousResponseId,
  }) {
    return _createResponse(
      instructions: instructions,
      tools: tools,
      previousResponseId: previousResponseId,
      input: outputs.map((output) => output.toJson()).toList(),
    );
  }

  Future<AiResponse> _createResponse({
    required String instructions,
    required List<AiToolDefinition> tools,
    required List<Map<String, dynamic>> input,
    String? previousResponseId,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiServiceException(
        'OpenAI API-ключ не настроен. Запустите приложение с '
        '--dart-define=OPENAI_API_KEY=ваш_ключ или подключите backend-proxy.',
      );
    }

    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final body = <String, dynamic>{
      'model': model,
      'instructions': instructions,
      'input': input,
      'tools': tools.map((tool) => tool.toJson()).toList(),
      'tool_choice': 'auto',
    };

    if (previousResponseId != null && previousResponseId.isNotEmpty) {
      body['previous_response_id'] = previousResponseId;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$normalizedBaseUrl/responses'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiServiceException(_errorMessage(response), cause: response.body);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const AiServiceException(
            'LLM вернула неожиданный формат ответа.');
      }
      return _parseResponse(decoded);
    } on AiServiceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AiServiceException(
        'LLM не ответила вовремя. Проверьте соединение и попробуйте ещё раз.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw AiServiceException(
        'Нет соединения с сервером LLM. Проверьте интернет.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw AiServiceException(
        'Не удалось выполнить HTTP-запрос к LLM.',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AiServiceException(
        'LLM вернула ответ, который не удалось прочитать как JSON.',
        cause: e,
      );
    }
  }

  AiResponse _parseResponse(Map<String, dynamic> json) {
    final calls = <AiFunctionCall>[];
    final output = json['output'];

    if (output is List) {
      for (final item in output) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] != 'function_call') continue;

        final name = item['name'];
        final callId = item['call_id'];
        if (name is! String || callId is! String) continue;

        calls.add(AiFunctionCall(
          name: name,
          callId: callId,
          arguments: _decodeArguments(item['arguments']),
        ));
      }
    }

    final topLevelText = json['output_text'];
    final text = topLevelText is String
        ? topLevelText.trim()
        : _extractMessageText(output).trim();

    return AiResponse(
      id: json['id'] as String?,
      text: text,
      functionCalls: calls,
      rawJson: json,
    );
  }

  Map<String, dynamic> _decodeArguments(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{};
  }

  String _extractMessageText(Object? output) {
    final parts = <String>[];

    void walk(Object? node) {
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
        return;
      }
      if (node is! Map<String, dynamic>) return;

      final type = node['type'];
      final text = node['text'];
      if ((type == 'output_text' || type == 'text') && text is String) {
        parts.add(text);
      }

      walk(node['content']);
    }

    walk(output);
    return parts.join('\n');
  }

  String _errorMessage(http.Response response) {
    String? apiMessage;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          apiMessage = error['message'] as String?;
        }
      }
    } catch (_) {
      // Ниже вернем понятную ошибку по статусу.
    }

    if (response.statusCode == 401) {
      return 'OpenAI отклонила API-ключ. Проверьте OPENAI_API_KEY.';
    }
    if (response.statusCode == 429) {
      return 'Превышен лимит запросов к LLM. Попробуйте позже.';
    }
    if (response.statusCode >= 500) {
      return 'Сервис LLM временно недоступен. Попробуйте позже.';
    }
    return apiMessage ??
        'Ошибка LLM API: HTTP ${response.statusCode}. Проверьте настройки.';
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
