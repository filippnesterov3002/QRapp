# Интеграция с Аксиома (Интерпроком)

## Обзор

Приложение поддерживает двусторонний обмен данными с системой **Аксиома (Интерпроком)** через WiFi-передачу в формате JSON.  
Формат файла совместим с таблицей `axioma.asset` базы данных Аксиомы (PostgreSQL-схема `axioma`).

---

## Структура файла обмена

Файл экспорта имеет следующий верхний уровень:

```json
{
  "version": "1.0",
  "exported_at": "2026-05-08T10:30:00",
  "app": "InventoryApp",
  "axioma_compatible": true,
  "items": [ ... ],
  "total": 50
}
```

### Поля записи предмета (`items[]`)

| Поле JSON | Таблица.Колонка Аксиомы | Тип | Описание |
|---|---|---|---|
| `assetnum` | `axioma.asset.assetnum` | varchar(12) | **Основной бизнес-ключ**. Уникален в рамках `siteid`. |
| `x_inventarnum` | `axioma.asset.x_inventarnum` | varchar(50) | Фактический инвентарный номер (кастомное поле). |
| `description` | `axioma.asset.description` | varchar(500) | Наименование / описание актива. |
| `classstructureid` | `axioma.asset.classstructureid` | varchar(20) | Ключ категории → JOIN `axioma.classstructure` для имени. |
| `reatroom` | `axioma.asset.reatroom` | varchar(30) | Помещение / кабинет (кастомное поле модуля REAT). |
| `location` | `axioma.asset.location` | varchar(30) | Код местонахождения → `axioma.locations`. |
| `orderqty` | `axioma.inventory.orderqty` | numeric(15,2) | Количество единиц. |
| `installdate` | `axioma.asset.installdate` | date | Дата ввода в эксплуатацию (аналог `created_at`). |
| `changedate` | `axioma.asset.changedate` | timestamp | Дата последнего изменения (`updated_at`). |
| `_category_name` | *(вспомогательное)* | string | Читаемое название категории, не хранится в Аксиоме. |

### Поля помещения (`rooms[]`) — в схеме `axioma_schema.json`

| Поле JSON | Таблица.Колонка Аксиомы | Описание |
|---|---|---|
| `location` | `axioma.locations.location` | Уникальный код местонахождения |
| `description` | `axioma.locations.description` | Название помещения |
| `reatroom` | `axioma.locations.reatroom` | Название кабинета (REAT) |
| `reatbuilding` | `axioma.locations.reatbuilding` | Здание (REAT) |
| `bimroomname` | `axioma.locations.bimroomname` | BIM-имя комнаты |
| `area` | `axioma.locations.area` | Площадь, м² |
| `typeloc` | `axioma.locations.typeloc` | Тип местонахождения |

---

## Маппинг полей

### Наши поля → поля Аксиомы

| Поле приложения | Поле Аксиомы | Таблица | Примечание |
|---|---|---|---|
| `item_id` (артикул) | `assetnum` | `axioma.asset` | Бизнес-ключ актива |
| — | `x_inventarnum` | `axioma.asset` | Дублируется для совместимости |
| `name` (наименование) | `description` | `axioma.asset` | |
| `category` (ключ категории) | `classstructureid` | `axioma.asset` | Ключ → JOIN `classstructure` |
| `location` (помещение) | `reatroom` | `axioma.asset` | Альтернатива: `axiroom` |
| `quantity` (количество) | `orderqty` | `axioma.inventory` | ⚠️ см. примечание ниже |
| `created_at` | `installdate` | `axioma.asset` | ⚠️ нет прямого created_at |
| `updated_at` | `changedate` | `axioma.asset` | |

### ⚠️ Нерешённые вопросы (УТОЧНИТЬ)

1. **Этаж (floor)** — поле `floor` отсутствует в `axioma.asset` и `axioma.locations`. Присутствует только в `axioma.dpauserinfo.floor` (таблица сотрудников). Уточнить у администратора Аксиомы.

2. **Количество** — в модели Аксиомы каждый объект (`asset`) является отдельной записью без поля `quantity` (каждый актив = 1 единица). Поле `orderqty` относится к таблице `axioma.inventory` (складские позиции). Уточнить логику учёта количества.

3. **Дата создания** — в `axioma.asset` нет явного поля `created_at`. Используется `installdate` (дата ввода в эксплуатацию) как приближение.

---

## Структура базы данных Аксиомы (ключевые таблицы)

| Таблица | Назначение |
|---|---|
| `axioma.asset` | Основной реестр активов / имущества |
| `axioma.locations` | Справочник местонахождений (помещений) |
| `axioma.classstructure` | Иерархия категорий (дерево классификатора) |
| `axioma.classification` | Корневые узлы классификатора |
| `axioma.item` | Каталог позиций (шаблоны) |
| `axioma.inventory` | Стоковые количества по позициям и местонахождениям |
| `axioma.assettrans` | Журнал перемещений активов |
| `axioma.assetspec` | Дополнительные атрибуты активов |

### SQL для выгрузки активов из Аксиомы

```sql
SELECT
    a.assetuid,
    a.assetnum,
    a.x_inventarnum,
    a.description,
    a.classstructureid,
    cs.description        AS category_name,
    a.assettype,
    a.location            AS location_code,
    l.description         AS location_name,
    a.reatbuilding,
    a.reatroom,
    a.axibuilding,
    a.axiroom,
    a.pluscphyloc,
    a.pluscassetdept,
    a.responsible,
    a.status,
    a.installdate,
    a.changedate,
    a.siteid,
    a.orgid
FROM axioma.asset a
LEFT JOIN axioma.locations l
    ON l.location = a.location AND l.siteid = a.siteid
LEFT JOIN axioma.classstructure cs
    ON cs.classstructureid = a.classstructureid
WHERE a.siteid = 'YOUR_SITE'   -- заменить на реальный siteid
ORDER BY a.assetnum;
```

---

## Как экспортировать данные в Аксиому

### Через WiFi-передачу (рекомендуется)

1. Откройте боковое меню → **📡 WiFi передача**
2. Нажмите **▶ Запустить сервер**
3. На компьютере откройте браузер, введите адрес с экрана (например `http://192.168.1.5:8080`)
4. В разделе **📥 Скачать данные с телефона** выберите нужные помещения
5. Нажмите **Скачать JSON файл** — файл скачается автоматически
6. Имя файла: `Инвентаризация_YYYY-MM-DD.json`

### Через Excel-экспорт

1. Откройте боковое меню → **📊 Выгрузка в Excel**
2. Выберите помещения и нажмите **Выгрузить**
3. Файл содержит колонки: №, Артикул, Наименование, Категория, Помещение, Количество, QR-данные, Дата добавления, Дата изменения

### Загрузка в Аксиому

Для загрузки JSON в Аксиому используйте один из вариантов:

**Вариант А — через интерфейс Аксиомы (импорт активов):**
- В Аксиоме: Администрирование → Загрузка данных → Активы
- Выберите файл JSON, настройте маппинг полей по таблице выше

**Вариант Б — прямая загрузка через SQL:**
```sql
-- Пример INSERT на основе данных из JSON
INSERT INTO axioma.asset (assetnum, x_inventarnum, description, classstructureid,
                          reatroom, location, changedate, siteid, orgid, ...)
VALUES (:assetnum, :x_inventarnum, :description, :classstructureid,
        :reatroom, :location, NOW(), 'YOUR_SITE', 'YOUR_ORG', ...);
```

---

## Как импортировать данные из Аксиомы

### Подготовка файла в Аксиоме

1. Выполните SQL-запрос из раздела выше
2. Экспортируйте результат в JSON (через pgAdmin, DBeaver или API Аксиомы)
3. Убедитесь что JSON содержит поле `"items": [...]`

### Загрузка через WiFi-передачу

1. Откройте боковое меню → **📡 WiFi передача**
2. Нажмите **▶ Запустить сервер**
3. На компьютере перейдите на страницу сервера
4. В разделе **📤 Загрузить данные на телефон**:
   - Нажмите «Выберите файл» → выберите JSON из Аксиомы
   - Нажмите **Загрузить JSON файл**
5. Если найдены дубликаты (по полю `assetnum`) — браузер спросит:
   - **OK** — обновить существующие записи данными из файла
   - **Отмена** — пропустить дубликаты, добавить только новые
6. После импорта отображается итог: добавлено / обновлено / новых помещений

### Загрузка через выбор файла (Excel-импорт)

1. Откройте боковое меню → **📂 Загрузка из Excel** *(если реализовано)*
2. Выберите файл `.json` или `.xlsx`
3. Приложение автоматически определит формат (InventoryApp или Аксиома) и применит нужный маппинг

### Поддерживаемые форматы при импорте

Приложение автоматически определяет формат по содержимому файла:

| Признак | Формат |
|---|---|
| `"app": "InventoryApp"` в корне | Наш формат |
| Наличие поля `assetnum` или `x_inventarnum` в записи | Формат Аксиомы |

При формате Аксиомы поля конвертируются автоматически:

| Поле Аксиомы | → Поле приложения |
|---|---|
| `assetnum` / `x_inventarnum` | `item_id` |
| `description` | `name` |
| `classstructureid` | `category` |
| `reatroom` / `axiroom` / `location` | `location` |
| `orderqty` | `quantity` |
| `installdate` / `commdate` | `created_at` |
| `changedate` | `updated_at` |
