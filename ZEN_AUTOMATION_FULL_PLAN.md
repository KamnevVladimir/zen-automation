# 🤖 Полная автоматизация генерации постов для Яндекс Дзен

## 📊 Цель проекта

Создать микросервис, который будет автоматически генерировать и публиковать **3-4 поста в день** на Яндекс Дзен про дешёвые путешествия с интеграцией бота @gdeVacationBot.

---

## 🏗️ Архитектура системы

### Компоненты

```
┌─────────────────────────────────────────────────────────────────┐
│                    Railway (Vapor Swift Backend)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1️⃣ SCHEDULER (Cron Jobs)                                       │
│     - 4 раза в день (8:00, 12:00, 16:00, 20:00 MSK)            │
│     - Триггерит генерацию поста                                  │
│                                                                   │
│  2️⃣ CONTENT GENERATOR (AI Engine)                               │
│     - OpenAI GPT-4 Turbo (генерация текста)                     │
│     - DALL-E 3 (генерация изображений)                          │
│     - Шаблонизатор контента                                      │
│     - Валидатор качества                                         │
│                                                                   │
│  3️⃣ DATA ANALYZER (Аналитика реальных данных)                  │
│     - Анализ поисков в боте                                      │
│     - Актуальные цены из Aviasales API                          │
│     - Трендовые направления                                      │
│                                                                   │
│  4️⃣ PUBLISHER (Публикация)                                      │
│     - Яндекс Дзен API (если доступен)                           │
│     - RSS-фид (альтернативный метод)                            │
│     - Резервный метод: Telegram Channel → Zen                   │
│                                                                   │
│  5️⃣ MONITORING (Мониторинг и уведомления)                      │
│     - Отслеживание публикаций                                    │
│     - Метрики (просмотры, дочитывания)                          │
│     - Уведомления в Telegram                                     │
│     - Логирование ошибок                                         │
│                                                                   │
│  6️⃣ STORAGE (База данных)                                       │
│     - PostgreSQL (Railway встроенная)                            │
│     - Хранение постов, метрик, шаблонов                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Технический стек

### Backend
- **Vapor 4** (Swift) — основной фреймворк
- **Fluent** — ORM для работы с БД
- **Queues** — для фоновых задач
- **PostgreSQL** — база данных (Railway)

### AI Services
- **OpenAI API** — генерация текста (GPT-4 Turbo)
- **DALL-E 3 API** — генерация изображений
- **Anthropic Claude** (опционально) — альтернатива GPT-4

### External APIs
- **Aviasales API** — актуальные цены на билеты
- **Яндекс Дзен API** — публикация (если доступен)
- **Telegram Bot API** — уведомления

### Infrastructure
- **Railway** — хостинг и CI/CD
- **Redis** (опционально) — кеш и очереди
- **GitHub Actions** — автоматизация деплоя

---

## 🗂️ Структура проекта

```
zenContentBot/
├── Package.swift
├── Dockerfile
├── railway.toml
├── .github/
│   └── workflows/
│       └── deploy.yml
├── Sources/
│   └── App/
│       ├── Application/
│       │   ├── configure.swift
│       │   ├── main.swift
│       │   └── routes.swift
│       ├── Domain/
│       │   ├── Entities/
│       │   │   ├── ZenPost.swift
│       │   │   ├── PostTemplate.swift
│       │   │   ├── GeneratedContent.swift
│       │   │   └── PublicationMetrics.swift
│       │   └── ValueObjects/
│       │       ├── PostCategory.swift
│       │       ├── PostStatus.swift
│       │       └── ContentQuality.swift
│       ├── Features/
│       │   ├── ContentGeneration/
│       │   │   ├── Services/
│       │   │   │   ├── ContentGeneratorService.swift
│       │   │   │   ├── OpenAIService.swift
│       │   │   │   ├── DallEService.swift
│       │   │   │   ├── TemplateEngine.swift
│       │   │   │   └── ContentValidator.swift
│       │   │   ├── Models/
│       │   │   │   ├── GenerationRequest.swift
│       │   │   │   ├── GenerationResponse.swift
│       │   │   │   └── ContentPrompt.swift
│       │   │   └── Jobs/
│       │   │       └── ContentGenerationJob.swift
│       │   ├── DataAnalysis/
│       │   │   ├── Services/
│       │   │   │   ├── TrendAnalyzer.swift
│       │   │   │   ├── PriceAggregator.swift
│       │   │   │   └── BotAnalyticsService.swift
│       │   │   └── Models/
│       │   │       ├── TrendingDestination.swift
│       │   │       └── PriceData.swift
│       │   ├── Publishing/
│       │   │   ├── Services/
│       │   │   │   ├── ZenAPIService.swift
│       │   │   │   ├── RSSPublisher.swift
│       │   │   │   └── TelegramPublisher.swift
│       │   │   └── Models/
│       │   │       ├── PublishRequest.swift
│       │   │       └── PublishResult.swift
│       │   ├── Monitoring/
│       │   │   ├── Services/
│       │   │   │   ├── MetricsCollector.swift
│       │   │   │   ├── AlertService.swift
│       │   │   │   └── TelegramNotifier.swift
│       │   │   └── Models/
│       │   │       └── PostMetrics.swift
│       │   └── Scheduler/
│       │       ├── Jobs/
│       │       │   ├── DailyPostJob.swift
│       │       │   └── MetricsCollectionJob.swift
│       │       └── ScheduleConfig.swift
│       ├── Infrastructure/
│       │   ├── Database/
│       │   │   ├── Migrations/
│       │   │   │   ├── CreateZenPosts.swift
│       │   │   │   ├── CreatePostTemplates.swift
│       │   │   │   └── CreatePostMetrics.swift
│       │   │   └── Models/
│       │   │       ├── ZenPostModel.swift
│       │   │       └── PostTemplateModel.swift
│       │   ├── ExternalAPIs/
│       │   │   ├── OpenAI/
│       │   │   │   ├── OpenAIClient.swift
│       │   │   │   └── OpenAIModels.swift
│       │   │   ├── Aviasales/
│       │   │   │   └── AviasalesClient.swift
│       │   │   └── Zen/
│       │   │       └── ZenClient.swift
│       │   └── DI/
│       │       └── ContainerSetup.swift
│       └── Shared/
│           ├── Config/
│           │   └── AppConfig.swift
│           ├── Extensions/
│           │   └── String+Sanitize.swift
│           └── Utilities/
│               ├── Logger+Zen.swift
│               └── DateFormatter+Zen.swift
├── Tests/
│   └── AppTests/
│       ├── ContentGenerationTests.swift
│       ├── TemplateEngineTests.swift
│       └── PublisherTests.swift
└── Resources/
    ├── Templates/
    │   ├── destination_post.json
    │   ├── lifehack_post.json
    │   ├── comparison_post.json
    │   └── budget_post.json
    └── Prompts/
        ├── system_prompts.json
        └── image_prompts.json
```

---

## 🎯 Workflow (как это работает)

### Шаг 1: Scheduler запускается (4 раза в день)

```
08:00 MSK → Пост про утренние направления ("Куда полететь на выходные")
12:00 MSK → Пост про бюджетные направления ("Отдых за 30,000₽")
16:00 MSK → Пост про лайфхаки ("5 способов сэкономить на билетах")
20:00 MSK → Пост про трендовые направления ("Топ-5 направлений недели")
```

### Шаг 2: Content Generator создаёт пост

```swift
1. Выбирает шаблон (из 10+ вариантов)
2. Анализирует данные из бота (популярные поиски)
3. Получает актуальные цены из Aviasales
4. Генерирует текст через GPT-4 (промпт + данные)
5. Генерирует 2-3 картинки через DALL-E 3
6. Валидирует контент (качество, уникальность, длина)
7. Интегрирует ссылку на бота (естественно)
```

### Шаг 3: Publisher публикует пост

```swift
1. Загружает картинки на хостинг (или в Zen напрямую)
2. Форматирует текст под Яндекс Дзен
3. Добавляет теги и мета-данные
4. Публикует через Zen API (или RSS)
5. Сохраняет результат в БД
```

### Шаг 4: Monitoring отслеживает результат

```swift
1. Через 1 час: собирает первые метрики
2. Через 24 часа: полный анализ поста
3. Отправляет уведомление в Telegram:
   "✅ Пост опубликован: [название]
    👁 Просмотры: 1,234
    📖 Дочитывания: 45%
    🔗 Переходы на бота: 23"
```

---

## 💡 Типы постов (шаблоны)

### 1. **Destination Post** (Направление + месяц)
```
Заголовок: "🌴 Куда полететь в [месяц] 2024: [страна] — всё, что нужно знать"
Структура:
- Вступление (зачем лететь именно туда)
- Погода и климат
- Цены (актуальные из Aviasales)
- Что посмотреть (топ-10)
- Практические советы
- Бюджеты (3 уровня)
- Интеграция бота (в разделе про цены)
Объём: 5000-7000 символов
Картинки: 3 (главная + 2 достопримечательности)
```

### 2. **Lifehack Post** (Лайфхак)
```
Заголовок: "💰 [число] секретов дешёвых авиабилетов, о которых не знают 90% туристов"
Структура:
- Интрига (почему это важно)
- Лайфхак 1 с примером
- Лайфхак 2 с примером
- ...
- Бонус-лайфхак (упоминание бота)
- Заключение
Объём: 3000-4000 символов
Картинки: 2 (главная + инфографика)
```

### 3. **Comparison Post** (Сравнение)
```
Заголовок: "🤔 [Страна 1] vs [Страна 2]: где дешевле отдохнуть в [месяц]?"
Структура:
- Вступление (дилемма выбора)
- Сравнение цен (таблица)
- Сравнение погоды
- Сравнение достопримечательностей
- Сравнение кухни
- Вердикт (для кого что подходит)
- Интеграция бота (в разделе про цены)
Объём: 4000-5000 символов
Картинки: 3 (по 1 на каждую страну + сводная)
```

### 4. **Budget Post** (Бюджет)
```
Заголовок: "💸 Отпуск за [сумма]₽: [число] стран, куда можно улететь прямо сейчас"
Структура:
- Вступление (миф о дорогих путешествиях)
- Страна 1 с разбивкой бюджета
- Страна 2 с разбивкой бюджета
- ...
- Советы по экономии
- Интеграция бота (мониторинг цен)
Объём: 3500-4500 символов
Картинки: 2 (главная + коллаж стран)
```

### 5. **Trending Post** (Тренды)
```
Заголовок: "🔥 Топ-[число] направлений недели: куда летят прямо сейчас"
Структура:
- Вступление (актуальность)
- Направление 1 (почему популярно + цена)
- Направление 2
- ...
- Статистика (из бота!)
- Интеграция бота (как узнавать о трендах первым)
Объём: 3000-4000 символов
Картинки: 2 (главная + график)
```

### 6. **Season Post** (Сезон)
```
Заголовок: "🍂 Осенний отпуск 2024: [число] недооценённых направлений"
Структура:
- Вступление (почему осень — лучшее время)
- Направление 1 (почему недооценено)
- Направление 2
- ...
- Советы по выбору
- Интеграция бота
Объём: 4000-5000 символов
Картинки: 3
```

### 7. **Weekend Post** (Выходные)
```
Заголовок: "✈️ [число] городов для идеального weekend-trip из Москвы"
Структура:
- Вступление (концепция короткого трипа)
- Город 1 (что успеть за 2-3 дня)
- Город 2
- ...
- Советы по планированию
- Интеграция бота
Объём: 3000-4000 символов
Картинки: 2
```

### 8. **Mistake Post** (Ошибки)
```
Заголовок: "❌ [число] ошибок при покупке авиабилетов, которые стоят вам денег"
Структура:
- Вступление (важность темы)
- Ошибка 1 (как избежать)
- Ошибка 2
- ...
- Интеграция бота (как избежать всех ошибок)
Объём: 3000-4000 символов
Картинки: 2
```

### 9. **Hidden Gem Post** (Скрытые жемчужины)
```
Заголовок: "💎 [число] мест, о которых не знают 99% туристов"
Структура:
- Вступление (секретные направления)
- Место 1 (почему неизвестно + как добраться)
- Место 2
- ...
- Советы путешественникам
- Интеграция бота
Объём: 4000-5000 символов
Картинки: 3
```

### 10. **Visa-Free Post** (Безвиз)
```
Заголовок: "🛂 [число] стран без визы для россиян в 2024: полный гид"
Структура:
- Вступление (преимущества безвиза)
- Страна 1 (условия + цены)
- Страна 2
- ...
- Таблица всех безвизовых стран
- Интеграция бота
Объём: 4000-5000 символов
Картинки: 2
```

---

## 🤖 Промпты для GPT-4

### System Prompt (главный)

```
Ты — эксперт по контент-маркетингу и путешествиям. Твоя задача — писать 
увлекательные, информативные статьи для Яндекс Дзен про дешёвые путешествия.

ПРАВИЛА:
1. Стиль: дружелюбный, но профессиональный. Как будто пишешь другу.
2. Структура: чёткая, с подзаголовками и списками.
3. Факты: только проверенные данные. Цены должны быть актуальными.
4. Уникальность: не копируй из интернета. Создавай оригинальный контент.
5. Интеграция бота: естественная, 1-2 раза в статье, в контексте.
6. Длина: 3000-7000 символов в зависимости от типа поста.
7. Эмодзи: используй умеренно (2-3 на абзац), для визуального разделения.
8. Призыв к действию: в конце статьи, мотивируй читателя.

ЗАПРЕЩЕНО:
- Кликбейт без содержания
- Ложная информация
- Плагиат
- Агрессивная реклама бота
- Орфографические ошибки
- Слишком длинные абзацы (макс. 5-7 строк)

ФОРМАТ ОТВЕТА: JSON
{
  "title": "Заголовок статьи (до 100 символов)",
  "subtitle": "Подзаголовок (до 200 символов, опционально)",
  "body": "Текст статьи (с разметкой для Дзен)",
  "tags": ["тег1", "тег2", "тег3", "тег4", "тег5"],
  "meta_description": "SEO-описание (до 160 символов)",
  "bot_integration_points": ["строка 1", "строка 2"],
  "image_prompts": [
    "Промпт для главной картинки",
    "Промпт для картинки 2",
    "Промпт для картинки 3"
  ],
  "estimated_read_time": 5,
  "target_audience": "budget_travelers | luxury_travelers | families | solo"
}
```

### User Prompt (для каждого типа поста)

**Пример для Destination Post:**
```
Создай статью типа "Destination Post" по следующим данным:

ТЕМА: Куда полететь в декабре 2024
СТРАНА: Таиланд
ГОРОДА: Бангкок, Пхукет, Самуи

АКТУАЛЬНЫЕ ДАННЫЕ:
- Цена билета Москва-Бангкок: 28,500₽ (по данным Aviasales на {date})
- Погода: 28-32°C, сухой сезон
- Популярность: +45% поисков в нашем боте за последнюю неделю

ТРЕБОВАНИЯ:
- Объём: 5000-6000 символов
- Фокус: пляжный отдых + культура
- Интеграция бота: в разделе про цены и в конце
- Целевая аудитория: семьи и пары

ДОПОЛНИТЕЛЬНО:
- Добавь раздел "Что взять с собой"
- Упомяни актуальные визовые правила
- Добавь совет про мониторинг цен (через бота)
```

---

## 🎨 Промпты для DALL-E 3

### Базовый шаблон

```
Create a professional, high-quality travel photography style image.

SUBJECT: {subject}
STYLE: Bright, vibrant, inviting, professional travel magazine aesthetic
LIGHTING: Natural, golden hour or soft daylight
COMPOSITION: Rule of thirds, balanced, no text overlays
COLORS: Warm and welcoming tones
MOOD: Inspiring, wanderlust-inducing
QUALITY: Ultra high-resolution, sharp focus

AVOID: Text, watermarks, people's faces in close-up, logos, dates

Aspect ratio: 16:9 for main image, 1:1 for thumbnails
```

### Примеры для разных типов

**Главное изображение (Hero image):**
```
Create a stunning aerial view of {destination} beach at golden hour. 
Crystal clear turquoise water, white sand, palm trees, traditional boats. 
Professional travel photography, National Geographic style, vibrant colors,
no text, 16:9 aspect ratio.
```

**Коллаж направлений:**
```
Create a beautiful collage showing 5 travel destinations: 
Thailand beach, Italian Colosseum, Dubai skyline, Greek islands, Turkish bazaar.
Each section should blend seamlessly. Bright, inviting colors.
Professional travel magazine style, no text, 16:9 aspect ratio.
```

**Инфографика (через дополнительный инструмент):**
```
Simple, minimalist travel infographic showing price comparison.
Modern design, clean layout, use icons instead of photos.
Color scheme: blue, orange, white. No text (we'll add it later).
1:1 aspect ratio.
```

---

## 📊 База данных (PostgreSQL)

### Таблицы

```sql
-- Посты
CREATE TABLE zen_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    subtitle VARCHAR(300),
    body TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}',
    meta_description VARCHAR(200),
    template_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'draft', -- draft, published, failed
    published_at TIMESTAMP,
    zen_article_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Картинки
CREATE TABLE zen_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES zen_posts(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    prompt TEXT NOT NULL,
    dalle_id VARCHAR(100),
    position INTEGER DEFAULT 0, -- 0 = main, 1+ = body images
    created_at TIMESTAMP DEFAULT NOW()
);

-- Метрики
CREATE TABLE zen_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES zen_posts(id) ON DELETE CASCADE,
    views INTEGER DEFAULT 0,
    reads INTEGER DEFAULT 0, -- дочитывания
    read_percentage FLOAT DEFAULT 0.0,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    bot_clicks INTEGER DEFAULT 0, -- переходы на бота
    collected_at TIMESTAMP DEFAULT NOW()
);

-- Шаблоны (для быстрого доступа)
CREATE TABLE post_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    system_prompt TEXT NOT NULL,
    user_prompt_template TEXT NOT NULL,
    image_prompt_template TEXT NOT NULL,
    min_length INTEGER DEFAULT 3000,
    max_length INTEGER DEFAULT 7000,
    estimated_read_time INTEGER DEFAULT 5,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Трендовые направления (кеш)
CREATE TABLE trending_destinations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    destination VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    search_count INTEGER DEFAULT 0,
    avg_price INTEGER,
    price_trend VARCHAR(20), -- up, down, stable
    last_updated TIMESTAMP DEFAULT NOW()
);

-- Логи генерации
CREATE TABLE generation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES zen_posts(id) ON DELETE CASCADE,
    step VARCHAR(50) NOT NULL, -- template, text_gen, image_gen, publish
    status VARCHAR(20) NOT NULL, -- success, failed
    error_message TEXT,
    duration_ms INTEGER,
    cost_usd DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX idx_posts_status ON zen_posts(status);
CREATE INDEX idx_posts_published_at ON zen_posts(published_at DESC);
CREATE INDEX idx_metrics_post_id ON zen_metrics(post_id);
CREATE INDEX idx_trending_search_count ON trending_destinations(search_count DESC);
```

---

## 🔧 Конфигурация (Environment Variables)

```bash
# Railway Environment Variables

# Database (автоматически от Railway)
DATABASE_URL=postgresql://...

# OpenAI API
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4-turbo-preview
OPENAI_MAX_TOKENS=4000
OPENAI_TEMPERATURE=0.7

# DALL-E API (часть OpenAI)
DALLE_MODEL=dall-e-3
DALLE_SIZE=1792x1024  # 16:9 для главных изображений
DALLE_QUALITY=hd

# Aviasales API
AVIASALES_API_KEY=...
AVIASALES_MARKER=your_marker_id

# Яндекс Дзен (если API доступен)
ZEN_API_KEY=...
ZEN_CHANNEL_ID=...

# Telegram Bot (для уведомлений)
TELEGRAM_BOT_TOKEN=8494700026:...
TELEGRAM_ADMIN_CHAT_ID=your_chat_id

# Scheduler (время в MSK)
SCHEDULER_TIMES=08:00,12:00,16:00,20:00
SCHEDULER_TIMEZONE=Europe/Moscow

# Content Settings
POSTS_PER_DAY=4
MIN_POST_LENGTH=3000
MAX_POST_LENGTH=7000
IMAGES_PER_POST=2-3

# Quality Control
ENABLE_CONTENT_VALIDATION=true
MIN_QUALITY_SCORE=0.7
CHECK_PLAGIARISM=true

# Monitoring
ENABLE_TELEGRAM_NOTIFICATIONS=true
METRICS_COLLECTION_INTERVAL=3600  # 1 час в секундах

# Bot Integration
BOT_USERNAME=gdeVacationBot
BOT_DEEP_LINK_BASE=https://t.me/gdeVacationBot?start=

# Logging
LOG_LEVEL=info  # debug, info, warning, error
```

---

## 💰 Стоимость и бюджет

### Ежедневные расходы

**4 поста в день:**

```
GPT-4 Turbo:
- ~3,000 токенов на вход (промпт + данные)
- ~6,000 токенов на выход (статья)
- Стоимость: ~$0.10 за prompt + ~$0.18 за completion
- Итого за пост: ~$0.28
- За 4 поста: ~$1.12/день

DALL-E 3:
- 2-3 изображения на пост
- Стоимость: $0.080 за HD изображение 1792x1024
- Итого за пост: ~$0.24 (3 изображения)
- За 4 поста: ~$0.96/день

Railway:
- Hobby Plan: $5/месяц
- PostgreSQL: включена в план
- Достаточно для нашей нагрузки

ИТОГО В ДЕНЬ: ~$2.08
ИТОГО В МЕСЯЦ: ~$62.40

БЮДЖЕТ С ЗАПАСОМ: $100/месяц
```

### Экономия

Можно снизить расходы:
- Использовать GPT-4o-mini вместо GPT-4 Turbo ($0.15 vs $0.30 за 1M токенов)
- Генерировать 2 картинки вместо 3
- Кешировать промпты и переиспользовать

**С оптимизацией: ~$40-50/месяц**

---

## 🚀 План внедрения

### Фаза 1: Подготовка (1-2 дня)

✅ **День 1:**
- Создать новый репозиторий на GitHub
- Настроить базовую структуру Vapor проекта
- Подключить Railway
- Настроить PostgreSQL
- Создать миграции для всех таблиц

✅ **День 2:**
- Интегрировать OpenAI API (текст)
- Интегрировать DALL-E 3 API (картинки)
- Создать базовый Content Generator
- Тестирование генерации первого поста вручную

### Фаза 2: Автоматизация (2-3 дня)

✅ **День 3:**
- Создать все 10 шаблонов постов
- Настроить Scheduler (4 раза в день)
- Интегрировать Aviasales API для актуальных цен
- Добавить анализ трендов из основного бота

✅ **День 4:**
- Создать Publisher (публикация постов)
- Интегрировать Яндекс Дзен API (или RSS)
- Добавить уведомления в Telegram
- Тестирование полного цикла

✅ **День 5:**
- Добавить сбор метрик
- Создать мониторинг качества
- Настроить логирование
- Добавить обработку ошибок

### Фаза 3: Запуск и мониторинг (1 неделя)

✅ **Неделя 1:**
- Запуск в production
- Генерация первых 28 постов (7 дней × 4 поста)
- Сбор метрик и фидбека
- Оптимизация промптов на основе результатов

### Фаза 4: Оптимизация (ongoing)

- Анализ самых успешных постов
- Улучшение промптов
- Добавление новых шаблонов
- A/B тестирование разных подходов

---

## 📈 Метрики успеха

### KPI для оценки эффективности

**Основные метрики:**
- Просмотры: > 500 на пост (через 24 часа)
- Дочитывания: > 40%
- Переходы на бота: > 3% от просмотров
- Лайки: > 2% от просмотров

**Цели по месяцам:**

```
Месяц 1 (тестовый):
- 120 постов (4 поста × 30 дней)
- 60,000 просмотров (500 на пост)
- 1,800 переходов на бота (3%)
- Анализ и оптимизация

Месяц 2-3 (рост):
- Увеличение просмотров до 1,000 на пост
- Увеличение CTR до 5%
- Добавление новых форматов

Месяц 4+ (масштабирование):
- Увеличение до 6-8 постов в день
- Кросс-постинг в другие платформы (VK, ТенЧат)
```

---

## 🛡️ Контроль качества

### Автоматическая валидация контента

```swift
struct ContentValidator {
    func validate(_ content: GeneratedContent) -> ValidationResult {
        var issues: [String] = []
        var score: Double = 1.0
        
        // 1. Проверка длины
        if content.body.count < 3000 {
            issues.append("Текст слишком короткий")
            score -= 0.2
        }
        if content.body.count > 10000 {
            issues.append("Текст слишком длинный")
            score -= 0.1
        }
        
        // 2. Проверка структуры
        if !content.body.contains("##") {
            issues.append("Отсутствуют подзаголовки")
            score -= 0.15
        }
        
        // 3. Проверка интеграции бота
        let botMentions = content.body.matches(of: "@gdeVacationBot").count
        if botMentions == 0 {
            issues.append("Нет упоминания бота")
            score -= 0.3
        } else if botMentions > 3 {
            issues.append("Слишком много упоминаний бота")
            score -= 0.2
        }
        
        // 4. Проверка уникальности (против предыдущих постов)
        let similarity = checkSimilarity(content)
        if similarity > 0.7 {
            issues.append("Контент слишком похож на предыдущие посты")
            score -= 0.4
        }
        
        // 5. Проверка на запрещённые слова
        let bannedWords = ["100%", "гарантия", "секрет века"]
        for word in bannedWords {
            if content.body.lowercased().contains(word) {
                issues.append("Содержит запрещённое слово: \(word)")
                score -= 0.1
            }
        }
        
        return ValidationResult(
            isValid: score >= 0.7,
            score: score,
            issues: issues
        )
    }
}
```

### Ручная модерация (опционально)

Если нужен дополнительный контроль:
- Все посты сначала сохраняются как черновики
- Отправляется уведомление в Telegram с превью
- Кнопки: ✅ Опубликовать | ✏️ Редактировать | ❌ Отклонить
- Автопубликация через 30 минут, если нет реакции

---

## 🔄 Резервные варианты

### Если Яндекс Дзен API недоступен

**Вариант 1: RSS-фид**
- Создаём RSS-канал на нашем сервере
- Подключаем его к Яндекс Дзен
- Дзен автоматически подтянет новые посты

**Вариант 2: Telegram Channel → Zen**
- Публикуем в Telegram канал
- Дзен может импортировать из Telegram автоматически

**Вариант 3: Полуавтоматическая публикация**
- Генерируем контент автоматически
- Сохраняем в админ-панель
- Публикуем вручную через веб-интерфейс Дзен (копипаст)

---

## 📱 Админ-панель (Web UI)

Простой веб-интерфейс для управления:

### Страницы:

1. **Dashboard**
   - Статистика за день/неделю/месяц
   - График публикаций
   - Топ-5 постов по просмотрам

2. **Posts**
   - Список всех постов
   - Фильтры (статус, дата, тип)
   - Превью и редактирование

3. **Templates**
   - Управление шаблонами
   - Редактирование промптов
   - Тестирование генерации

4. **Analytics**
   - Детальная аналитика по постам
   - Переходы на бота (по UTM)
   - ROI расчёты

5. **Settings**
   - Конфигурация расписания
   - API ключи
   - Уведомления

---

## 🎯 Итоговый чек-лист

### Что нужно для старта:

✅ **Технические требования:**
- [ ] Создать репозиторий на GitHub
- [ ] Подключить Railway
- [ ] Получить OpenAI API ключ ($100 на счету)
- [ ] Настроить PostgreSQL
- [ ] Получить доступ к Яндекс Дзен API (или RSS)
- [ ] Настроить Telegram бота для уведомлений

✅ **Контент:**
- [ ] Подготовить 10 шаблонов постов
- [ ] Написать промпты для GPT-4
- [ ] Написать промпты для DALL-E 3
- [ ] Создать список ключевых слов и тегов

✅ **Интеграции:**
- [ ] Подключить Aviasales API
- [ ] Подключить аналитику основного бота
- [ ] Настроить UTM-метки для отслеживания

✅ **Тестирование:**
- [ ] Сгенерировать 5 тестовых постов
- [ ] Проверить качество контента
- [ ] Проверить уникальность
- [ ] Опубликовать вручную для теста

---

## 🚀 Готовность к запуску

**Когда все пункты выполнены:**
1. Создаём новый репозиторий
2. Я разворачиваю полную структуру проекта
3. Настраиваем все интеграции
4. Запускаем в тестовом режиме на 3 дня
5. Анализируем результаты
6. Запускаем на полную мощность (4 поста/день)

**Ожидаемый результат через месяц:**
- 120 качественных постов на Яндекс Дзен
- 60,000-120,000 просмотров
- 1,800-6,000 переходов на бота
- Автоматическая генерация без участия человека

---

## 💡 Дополнительные возможности (будущее)

После успешного запуска можно добавить:

1. **Кросс-постинг**
   - Автоматическая публикация в VK
   - Автоматическая публикация в ТенЧат
   - Адаптация контента под каждую платформу

2. **Видео-контент**
   - Генерация коротких видео (30-60 сек)
   - Озвучка текста через TTS
   - Публикация в YouTube Shorts / VK Клипы

3. **Персонализация**
   - Разные версии поста для разных аудиторий
   - A/B тестирование заголовков
   - Оптимизация времени публикации

4. **Интеграция с соцсетями**
   - Автоматический постинг анонсов
   - Ответы на комментарии через AI
   - Сбор обратной связи

---

## 📞 Следующие шаги

**Когда будешь готов:**
1. Создай новый репозиторий на GitHub (название: `zenContentBot`)
2. Скинь мне ссылку
3. Я разверну полную структуру проекта
4. Настроим Railway вместе
5. Запустим!

**Вопросы для уточнения:**
- Есть ли доступ к Яндекс Дзен API? (или будем через RSS?)
- Какой бюджет на OpenAI в месяц? ($50-100?)
- Нужна ли ручная модерация или полный автомат?
- Какие темы в приоритете? (страны, лайфхаки, бюджеты?)

---

**Готов начинать? 🚀**

