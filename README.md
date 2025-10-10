# 🤖 Zen Automation

Автоматизированная система генерации и публикации постов для Яндекс Дзен про дешёвые путешествия.

## 🚀 Особенности

- **Автоматическая генерация**: 4 поста в день по расписанию
- **AI-контент**: GPT-4 Turbo для текста, DALL-E 3 для изображений
- **10 типов постов**: направления, лайфхаки, сравнения, бюджеты и др.
- **Качественный контент**: валидация, проверка уникальности
- **Интеграция бота**: естественное упоминание @gdeVacationBot
- **Мониторинг**: уведомления в Telegram, метрики, логи

## 📦 Технологии

- **Backend**: Vapor 4 (Swift)
- **Database**: PostgreSQL (Railway)
- **AI**: OpenAI GPT-4 Turbo, DALL-E 3
- **Deploy**: Railway с автоматическим CI/CD
- **Notifications**: Telegram Bot API

## 🏗️ Архитектура

```
┌─────────────────────────────────────┐
│         Scheduler (4x day)          │
├─────────────────────────────────────┤
│      Content Generator (AI)         │
├─────────────────────────────────────┤
│      Content Validator              │
├─────────────────────────────────────┤
│      Publisher (Zen API)            │
├─────────────────────────────────────┤
│      Monitoring & Notifications     │
└─────────────────────────────────────┘
```

## 📋 Требования

- Swift 5.9+
- PostgreSQL 14+
- OpenAI API key
- Telegram Bot Token (для уведомлений)

## 🔧 Установка

### Локальная разработка

```bash
# Клонируем репозиторий
git clone git@github.com:KamnevVladimir/zen-automation.git
cd zen-automation

# Копируем .env.example в .env
cp Sources/App/.env.example .env

# Редактируем .env и добавляем свои API ключи
nano .env

# Собираем проект
swift build

# Запускаем
swift run

# Или с тестами
swift test | xcsift
```

### Railway Deploy

1. Подключите GitHub репозиторий к Railway
2. Добавьте PostgreSQL сервис
3. Настройте environment variables (см. .env.example)
4. Railway автоматически развернёт приложение

## 🔐 Environment Variables

```bash
# OpenAI
OPENAI_API_KEY=sk-your-key
OPENAI_MODEL=gpt-4-turbo-preview

# Database (Railway provides automatically)
DATABASE_URL=postgresql://...

# Telegram
TELEGRAM_BOT_TOKEN=your-token
TELEGRAM_ADMIN_CHAT_ID=your-chat-id

# Bot Integration
BOT_USERNAME=gdeVacationBot

# Content Settings
POSTS_PER_DAY=4
MIN_POST_LENGTH=3000
MAX_POST_LENGTH=7000
```

## 📅 Расписание постов

- **08:00 MSK** - Weekend Post (выходные направления)
- **12:00 MSK** - Budget Post (бюджетные страны)
- **16:00 MSK** - Lifehack Post (лайфхаки)
- **20:00 MSK** - Trending Post (тренды недели)

## 📊 API Endpoints

```bash
# Health check
GET /health

# Список постов
GET /api/v1/posts

# Метрики
GET /api/v1/metrics

# Генерация поста (manual trigger)
POST /api/v1/generate
Content-Type: application/json
{
  "templateType": "destination",
  "topic": "Таиланд в декабре",
  "destinations": ["Бангкок", "Пхукет"]
}
```

## 🧪 Тестирование

```bash
# Запуск всех тестов
swift test

# С форматированием через xcsift
swift test | xcsift

# Конкретный тест
swift test --filter ContentGeneratorTests
```

## 📈 Метрики

Система автоматически собирает метрики:
- Количество постов (всего/опубликовано)
- Время генерации
- Стоимость API вызовов
- Качество контента (validation score)

## 🔍 Мониторинг

Уведомления в Telegram:
- ✅ Успешная публикация поста
- ❌ Ошибки генерации
- 📊 Дневная статистика
- 💰 Расходы на API

## 💰 Стоимость

Примерные расходы:
- GPT-4 Turbo: ~$0.28 за пост
- DALL-E 3: ~$0.24 за пост (3 изображения)
- **Итого**: ~$2-3 в день (~$60-90 в месяц)

## 🔧 Development

### Структура проекта

```
Sources/App/
├── Application/          # Конфигурация, роуты, main
├── Domain/              # Бизнес-логика, энтити
├── Features/            # Фичи (генерация, публикация, etc)
├── Infrastructure/      # БД, внешние API
└── Shared/             # Утилиты, конфиг

Tests/AppTests/         # Тесты
Resources/              # Шаблоны, промпты
```

### Добавление нового типа поста

1. Добавить в `PostCategory` enum
2. Создать промпт в `ContentPrompt`
3. Добавить в расписание `ScheduleConfig`
4. Написать тесты

## 🤝 Contributing

1. Fork репозиторий
2. Создайте feature branch
3. Commit изменения
4. Push в branch
5. Создайте Pull Request

## 📝 License

MIT

## 👨‍💻 Автор

Vladimir Kamnev

---

## 🔗 Полезные ссылки

- [Vapor Documentation](https://docs.vapor.codes/)
- [OpenAI API](https://platform.openai.com/docs)
- [Railway Docs](https://docs.railway.app/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

---

**Сделано с ❤️ для путешественников**

