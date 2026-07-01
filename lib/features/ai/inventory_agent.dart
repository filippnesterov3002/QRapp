import 'dart:convert';

import 'ai_service.dart';
import 'inventory_repository.dart';

class AgentReply {
  final String text;
  final bool isError;

  const AgentReply({
    required this.text,
    this.isError = false,
  });
}

/// Оркестратор диалога: LLM -> function call -> локальный инструмент -> LLM.
class InventoryAgent {
  final AiService _aiService;
  final InventoryRepository _repository;
  String? _previousResponseId;

  InventoryAgent({
    AiService? aiService,
    InventoryRepository? repository,
  })  : _aiService = aiService ?? AiService(),
        _repository = repository ?? InventoryRepository();

  factory InventoryAgent.createDefault() => InventoryAgent();

  Future<AgentReply> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const AgentReply(text: 'Напишите команду для инвентаря.');
    }

    try {
      var response = await _aiService.sendUserMessage(
        message: trimmed,
        instructions: _buildInstructions(),
        tools: _tools,
        previousResponseId: _previousResponseId,
      );
      _previousResponseId = response.id ?? _previousResponseId;

      var toolRound = 0;
      while (response.hasFunctionCalls && toolRound < 4) {
        final previousId = response.id ?? _previousResponseId;
        if (previousId == null) {
          return const AgentReply(
            text:
                'LLM не вернула идентификатор ответа для продолжения диалога.',
            isError: true,
          );
        }

        final outputs = <AiToolOutput>[];
        for (final call in response.functionCalls) {
          final toolResult = await _executeTool(call);
          outputs.add(AiToolOutput(
            callId: call.callId,
            output: jsonEncode(toolResult.toJson()),
          ));
        }

        response = await _aiService.submitToolOutputs(
          outputs: outputs,
          instructions: _buildInstructions(),
          tools: _tools,
          previousResponseId: previousId,
        );
        _previousResponseId = response.id ?? previousId;
        toolRound++;
      }

      if (response.hasFunctionCalls) {
        return const AgentReply(
          text:
              'Я остановился после нескольких действий. Уточните следующий шаг.',
          isError: true,
        );
      }

      return AgentReply(
        text: response.text.isNotEmpty
            ? response.text
            : 'Готово. Данные инвентаря обновлены.',
      );
    } on AiServiceException catch (e) {
      return AgentReply(text: e.message, isError: true);
    } catch (e) {
      return AgentReply(
        text: 'Не удалось обработать команду: $e',
        isError: true,
      );
    }
  }

  void resetConversation() {
    _previousResponseId = null;
  }

  Future<ToolExecutionResult> _executeTool(AiFunctionCall call) async {
    try {
      switch (call.name) {
        case 'add_inventory_item':
          return _repository.addItem(AddItemParams.fromJson(call.arguments));
        case 'update_inventory_quantity':
          return _repository.updateQuantity(
            UpdateQuantityParams.fromJson(call.arguments),
          );
        case 'move_inventory_item':
          return _repository.moveItem(MoveItemParams.fromJson(call.arguments));
        case 'dispose_inventory_item':
          return _repository.disposeItem(
            DisposeItemParams.fromJson(call.arguments),
          );
        default:
          return ToolExecutionResult(
            success: false,
            message: 'Неизвестный инструмент: ${call.name}.',
          );
      }
    } catch (e) {
      return ToolExecutionResult(
        success: false,
        message: 'Ошибка выполнения инструмента ${call.name}: $e',
      );
    }
  }

  String _buildInstructions() => '''
Ты ИИ-агент мобильного приложения инвентаризации.
Отвечай на языке пользователя: русский по умолчанию, английский если пользователь пишет по-английски.

Твоя задача: помогать управлять предметами инвентаря через доступные инструменты.
Используй инструменты для любых изменений данных: добавления, изменения количества, перемещения, удаления или списания.
Не выдумывай факты о предметах. Если данных не хватает или найдено несколько предметов, задай один короткий уточняющий вопрос.

Правила:
- Для добавления нужны name, quantity, location, category. description и serial_number опциональны.
- serial_number сохраняется в поле inventoryNumber текущей модели данных.
- Для количества используй operation: increase, decrease или set.
- Для "спиши" используй dispose_inventory_item с mode=write_off.
- Для "удали" используй dispose_inventory_item с mode=delete.
- Не показывай пользователю JSON, имена функций и внутренние аргументы.
- После успешного действия кратко скажи, что изменено.

Категории:
- furniture: Мебель
- tech: Техника
- office_tech: Оргтехника
- supplies: Расходники
- tools: Инструменты

Текущий снимок инвентаря:
${_repository.buildInventorySnapshot()}
''';

  List<AiToolDefinition> get _tools => const [
        AiToolDefinition(
          name: 'add_inventory_item',
          description:
              'Добавить новый предмет инвентаря с названием, количеством, местоположением, категорией, описанием и серийным номером.',
          parameters: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Название предмета, например "стул".',
              },
              'quantity': {
                'type': 'integer',
                'description': 'Количество предметов, целое число больше 0.',
              },
              'location': {
                'type': 'string',
                'description': 'Местоположение, например "комната 201".',
              },
              'category': {
                'type': 'string',
                'enum': [
                  'furniture',
                  'tech',
                  'office_tech',
                  'supplies',
                  'tools',
                ],
                'description': 'Категория предмета.',
              },
              'description': {
                'type': ['string', 'null'],
                'description': 'Описание предмета или null.',
              },
              'serial_number': {
                'type': ['string', 'null'],
                'description': 'Серийный или инвентарный номер или null.',
              },
            },
            'required': [
              'name',
              'quantity',
              'location',
              'category',
              'description',
              'serial_number',
            ],
          },
        ),
        AiToolDefinition(
          name: 'update_inventory_quantity',
          description:
              'Изменить количество существующего предмета: увеличить, уменьшить или установить точное значение.',
          parameters: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'name': {
                'type': ['string', 'null'],
                'description': 'Название предмета или null.',
              },
              'item_id': {
                'type': ['string', 'null'],
                'description': 'Артикул itemId, например ITEM-001, или null.',
              },
              'inventory_number': {
                'type': ['string', 'null'],
                'description': 'Инвентарный или серийный номер или null.',
              },
              'location': {
                'type': ['string', 'null'],
                'description': 'Местоположение для уточнения поиска или null.',
              },
              'operation': {
                'type': 'string',
                'enum': ['increase', 'decrease', 'set'],
                'description': 'Операция изменения количества.',
              },
              'quantity': {
                'type': 'integer',
                'description':
                    'Дельта для increase/decrease или новое значение для set.',
              },
            },
            'required': [
              'name',
              'item_id',
              'inventory_number',
              'location',
              'operation',
              'quantity',
            ],
          },
        ),
        AiToolDefinition(
          name: 'move_inventory_item',
          description:
              'Переместить существующий предмет в другое местоположение.',
          parameters: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'name': {
                'type': ['string', 'null'],
                'description': 'Название предмета или null.',
              },
              'item_id': {
                'type': ['string', 'null'],
                'description': 'Артикул itemId или null.',
              },
              'inventory_number': {
                'type': ['string', 'null'],
                'description': 'Инвентарный или серийный номер или null.',
              },
              'from_location': {
                'type': ['string', 'null'],
                'description': 'Текущее местоположение или null.',
              },
              'to_location': {
                'type': 'string',
                'description': 'Новое местоположение.',
              },
            },
            'required': [
              'name',
              'item_id',
              'inventory_number',
              'from_location',
              'to_location',
            ],
          },
        ),
        AiToolDefinition(
          name: 'dispose_inventory_item',
          description: 'Удалить предмет или отметить его как списанный.',
          parameters: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'name': {
                'type': ['string', 'null'],
                'description': 'Название предмета или null.',
              },
              'item_id': {
                'type': ['string', 'null'],
                'description': 'Артикул itemId или null.',
              },
              'inventory_number': {
                'type': ['string', 'null'],
                'description': 'Инвентарный или серийный номер или null.',
              },
              'location': {
                'type': ['string', 'null'],
                'description': 'Местоположение для уточнения поиска или null.',
              },
              'mode': {
                'type': 'string',
                'enum': ['write_off', 'delete'],
                'description':
                    'write_off для списания, delete для полного удаления.',
              },
            },
            'required': [
              'name',
              'item_id',
              'inventory_number',
              'location',
              'mode',
            ],
          },
        ),
      ];

  void dispose() {
    _aiService.dispose();
  }
}
