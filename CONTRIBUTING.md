# Contributing to Zen Automation

Спасибо за интерес к проекту! 🎉

## Рабочий процесс

1. **Fork** репозитория
2. **Clone** свой fork
3. Создайте **feature branch** (`git checkout -b feature/amazing-feature`)
4. **Commit** изменения (`git commit -m 'feat: добавить потрясающую фичу'`)
5. **Push** в branch (`git push origin feature/amazing-feature`)
6. Откройте **Pull Request**

## Стандарты кода

### Commit Messages

Используем Conventional Commits:

- `feat:` - новая функциональность
- `fix:` - исправление бага
- `docs:` - изменения в документации
- `test:` - добавление/изменение тестов
- `refactor:` - рефакторинг кода
- `style:` - форматирование кода
- `chore:` - обновление зависимостей и т.д.

Примеры:
```
feat: добавить генерацию постов типа "сезон"
fix: исправить валидацию контента
docs: обновить README
test: добавить тесты для ContentValidator
```

Сообщения должны быть:
- **Краткими** (до 50 символов)
- **На русском языке**
- **В повелительном наклонении** ("добавить", а не "добавил")

### Стиль кода

- Используйте **Swift 5.9+**
- Следуйте **Swift API Design Guidelines**
- Используйте **4 пробела** для отступов
- **Максимум 500 строк** на файл
- **1-2 сущности** на файл

### Тестирование

**Обязательно:**
- ✅ Покрытие тестами ≥ 90%
- ✅ Все тесты должны проходить
- ✅ Test-first подход: пишем тесты → пишем код

**Запуск тестов:**
```bash
make test
# или с xcsift
make test-xcsift
```

**Проверка покрытия:**
```bash
make test-coverage
```

### Структура проекта

Следуйте существующей архитектуре:

```
Sources/App/
├── Application/      # Конфигурация
├── Domain/          # Бизнес-логика
├── Features/        # Фичи (генерация, публикация)
├── Infrastructure/  # БД, внешние API
└── Shared/         # Утилиты
```

### Pull Request Guidelines

**Перед созданием PR:**

1. Убедитесь что все тесты проходят
2. Проверьте покрытие кода
3. Обновите документацию (если нужно)
4. Проверьте линтер: `make lint`

**Описание PR должно включать:**

- 📝 Что изменено
- 🎯 Зачем (какую проблему решает)
- 🧪 Как протестировано
- 📸 Скриншоты (если UI изменения)

## Разработка

### Первый запуск

```bash
# Клонируем
git clone git@github.com:KamnevVladimir/zen-automation.git
cd zen-automation

# Инициализация
make init

# Редактируем .env
nano .env

# Сборка
make build

# Тесты
make test

# Запуск
make run
```

### Локальная разработка

```bash
# Автоматическая пересборка при изменениях
swift run

# Docker локально
make docker-build
make docker-run
```

### Добавление новой фичи

1. **Создайте ветку**
```bash
git checkout -b feature/new-post-type
```

2. **Напишите тесты**
```swift
// Tests/AppTests/NewFeatureTests.swift
import XCTest
@testable import App

final class NewFeatureTests: XCTestCase {
    func testNewFeature() throws {
        // Тест вашей фичи
    }
}
```

3. **Реализуйте фичу**
```swift
// Sources/App/Features/NewFeature/...
```

4. **Запустите тесты**
```bash
make test
```

5. **Создайте PR**

## Вопросы?

- 📧 Email: [ваш email]
- 💬 Telegram: @your_username
- 🐛 Issues: [GitHub Issues](https://github.com/KamnevVladimir/zen-automation/issues)

## Code of Conduct

- Будьте уважительны
- Помогайте другим
- Принимайте конструктивную критику
- Фокусируйтесь на том, что лучше для проекта

## Лицензия

Делая вклад в проект, вы соглашаетесь что ваш код будет под MIT лицензией.

---

**Спасибо за ваш вклад! 🙏**

