import ast
import operator


class SimpleAgent:
    def __init__(self, llm):
        self.llm = llm
        self.state: dict[str, list | int] = {"history": [], "attempts": 0}

    def run(self, task: str) -> str:
        """Запускает цикл агента: Reason → Act → Observe"""
        self.state["history"].append(f"Задача: {task}")

        # REASON: LLM принимает решение на основе контекста
        decision = self.llm.chat(f"""
            Задача: {task}
            История: {self.state['history'][-3:]}
            Доступные инструменты: ['calculator', 'search']
            Какой инструмент использовать? Отвечай только названием.
        """).strip().lower()

        # ACT: Выполняем действие через инструмент
        if "калькулятор" in decision or "calculator" in decision:
            result = self._safe_calculate(task)
        else:
            result = self._mock_search(task)

        # OBSERVE: Обновляем состояние
        self.state["history"].append(f"Действие: {decision} → Результат: {result}")
        self.state["attempts"] += 1
        return result

    def _safe_calculate(self, expr: str) -> float | str:
        """
        Безопасный вычислитель: только арифметические операции.
        Использует AST-парсинг с белым списком операторов.
        """
        operators: dict[type[ast.operator], callable] = {
            ast.Add: operator.add, ast.Sub: operator.sub,
            ast.Mult: operator.mul, ast.Div: operator.truediv,
            ast.Pow: operator.pow, ast.USub: operator.neg,
        }

        def _eval_node(node: ast.AST) -> float:
            if isinstance(node, ast.Constant):
                return node.value  # type: ignore[no-any-return]
            if isinstance(node, ast.BinOp):
                op_type = type(node.op)
                if op_type not in operators:
                    raise ValueError(f"Небезопасная операция: {op_type.__name__}")
                return operators[op_type](
                    _eval_node(node.left), _eval_node(node.right)
                )
            if isinstance(node, ast.UnaryOp):
                op_type = type(node.op)
                if op_type not in operators:
                    raise ValueError(f"Небезопасная операция: {op_type.__name__}")
                return operators[op_type](_eval_node(node.operand))
            raise ValueError(f"Неподдерживаемый узел AST: {type(node).__name__}")

        try:
            tree = ast.parse(expr.strip(), mode='eval')
            return _eval_node(tree.body)
        except Exception:
            return "Ошибка: недопустимое выражение"

    def _mock_search(self, query: str) -> str:
        """Заглушка поиска — в реальности здесь будет вызов API"""
        return f"Найдено по запросу: {query[:50]}..."
