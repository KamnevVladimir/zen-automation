# 🔑 Полная инструкция по настройке Zen Automation

Пошаговый гайд как получить все API ключи и настроить проект.

---

## 📋 Что понадобится

- [ ] AI провайдер (Anthropic Claude / OpenAI / YandexGPT)
- [ ] Провайдер изображений (Stability AI / DALL-E / Kandinsky)
- [ ] Telegram Bot (для уведомлений)
- [ ] Railway аккаунт (для хостинга)
- [ ] Яндекс Дзен канал (для публикации)

---

## 1️⃣ Anthropic Claude API (Рекомендуется 🔥)

**Почему Claude:**
- ✅ Работает из России
- ✅ Лучше понимает русский язык
- ✅ Дешевле OpenAI (~$3 за 1M токенов vs $10)
- ✅ Claude 3.5 Sonnet - топовая модель

### Как получить ключ:

1. Зайдите на [console.anthropic.com](https://console.anthropic.com/)
2. Зарегистрируйтесь (нужна карта Visa/Mastercard не из РФ)
3. Перейдите в **API Keys** → **Create Key**
4. Скопируйте ключ (начинается с `sk-ant-...`)
5. Пополните баланс: **Billing** → **Add Credits** (минимум $5)

**Стоимость:**
- Claude 3.5 Sonnet: $3 / 1M input tokens, $15 / 1M output
- ~$0.15 за пост (в 2 раза дешевле GPT-4)

**Где получить карту:**
- Wise (wise.com) - виртуальная карта
- Payoneer - карта для фрилансеров
- Revolut (через друзей из Европы)

---

## 2️⃣ Stability AI (для изображений) (Рекомендуется 🔥)

**Почему Stability AI:**
- ✅ Работает из России
- ✅ Дешевле DALL-E ($0.04 vs $0.08 за изображение)
- ✅ Stable Diffusion XL - качественные картинки
- ✅ Больше контроля над стилем

### Как получить ключ:

1. Зайдите на [platform.stability.ai](https://platform.stability.ai/)
2. Sign Up (можно через Google)
3. **API Keys** → **Create Key**
4. Скопируйте ключ (начинается с `sk-...`)
5. Купите кредиты: **Billing** → минимум $10

**Стоимость:**
- SDXL 1024x1792: $0.04 за изображение
- ~$0.12 за пост (3 картинки)

---

## 3️⃣ OpenAI API (если разблокируют)

### Как получить:

1. Зайдите на [platform.openai.com](https://platform.openai.com/)
2. Sign Up
3. **API Keys** → **Create new secret key**
4. Скопируйте ключ (начинается с `sk-...`)
5. Пополните: **Billing** → минимум $5

**Проблема:** Блокирует IP из России.

**Решения:**
- VPN (Outline, Shadowsocks)
- Прокси резидентный
- Купить аккаунт (не рекомендую)

---

## 4️⃣ YandexGPT + Kandinsky (российская альтернатива)

**Плюсы:**
- ✅ Работает из России без VPN
- ✅ Понимает русский на 100%
- ✅ Дешевле западных аналогов

**Минусы:**
- ⚠️ Качество текста хуже Claude/GPT-4
- ⚠️ Меньше токенов (8K vs 200K)

### YandexGPT:

1. Зайдите на [cloud.yandex.ru](https://cloud.yandex.ru/)
2. Создайте аккаунт (нужна карта МИР)
3. Создайте **Cloud** и **Folder**
4. Перейдите в **YandexGPT API**
5. Создайте **API-ключ**
6. Скопируйте Folder ID и API Key

**Стоимость:** ~150₽ за 1M токенов

### Kandinsky (для изображений):

1. [fusionbrain.ai](https://fusionbrain.ai/)
2. Регистрация
3. API → Получить ключ

**Стоимость:** Бесплатно! (пока)

---

## 5️⃣ Telegram Bot (для уведомлений)

### Создание бота:

1. Откройте Telegram
2. Найдите [@BotFather](https://t.me/BotFather)
3. Отправьте `/newbot`
4. Придумайте имя: `Zen Automation Bot`
5. Придумайте username: `zen_automation_bot`
6. Скопируйте токен (вида `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

### Получение Chat ID:

1. Напишите своему боту любое сообщение
2. Откройте в браузере:
   ```
   https://api.telegram.org/bot<ВАШ_ТОКЕН>/getUpdates
   ```
3. Найдите `"chat":{"id":123456789}`
4. Это ваш Chat ID

**ИЛИ** проще:

1. Напишите [@userinfobot](https://t.me/userinfobot)
2. Он вышлет ваш Chat ID

---

## 6️⃣ Railway (хостинг)

### Регистрация:

1. Зайдите на [railway.app](https://railway.app/)
2. Sign Up через GitHub
3. **New Project**
4. **Deploy from GitHub repo**
5. Выберите `KamnevVladimir/zen-automation`

### Добавление PostgreSQL:

1. В проекте: **New** → **Database** → **PostgreSQL**
2. Railway автоматически создаст `DATABASE_URL`

### Environment Variables:

В разделе **Variables** добавьте:

```bash
# AI Provider (выбор модели)
AI_PROVIDER=anthropic  # openai / anthropic / yandexgpt

# Anthropic Claude (рекомендуется)
ANTHROPIC_API_KEY=sk-ant-your-key-here
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022

# Image Provider
IMAGE_PROVIDER=stability  # stability / dalle / kandinsky

# Stability AI (рекомендуется)
STABILITY_AI_KEY=sk-your-key-here

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl
TELEGRAM_ADMIN_CHAT_ID=123456789

# Database (автоматически)
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Bot Integration
BOT_USERNAME=gdeVacationBot
```

**Опциональные переменные:**

```bash
# Content Settings
POSTS_PER_DAY=4
MIN_POST_LENGTH=3000
MAX_POST_LENGTH=7000

# Quality Control
ENABLE_CONTENT_VALIDATION=true
MIN_QUALITY_SCORE=0.7

# Logging
LOG_LEVEL=info
```

---

## 7️⃣ Яндекс Дзен (публикация)

### Метод 1: RSS (Рекомендуется)

**Самый простой способ:**

1. Зайдите в [zen.yandex.ru](https://zen.yandex.ru/)
2. Создайте канал (если нет)
3. **Настройки канала** → **RSS**
4. Включите импорт из RSS
5. Добавьте URL: `https://your-app.railway.app/api/v1/rss`
6. Дзен будет автоматически импортировать новые посты

**Плюсы:**
- ✅ Не нужен API ключ
- ✅ Автоматическая публикация
- ✅ Работает сразу

### Метод 2: Яндекс API (сложнее)

**Для полного контроля:**

1. Зарегистрируйтесь на [oauth.yandex.ru](https://oauth.yandex.ru/)
2. Создайте приложение
3. Получите **Client ID** и **Client Secret**
4. Пройдите OAuth авторизацию
5. Получите **Access Token**

**Проблема:** Яндекс API для Дзен закрыт для новых партнёров.

**Рекомендация:** Используйте RSS метод.

### Метод 3: Telegram Channel → Zen

**Альтернатива:**

1. Создайте Telegram канал
2. Подключите его к Дзену:
   - **Настройки канала** → **Кросспостинг** → **Telegram**
3. Модифицируйте код для публикации в Telegram вместо Дзен

---

## 8️⃣ Пошаговая настройка (всё вместе)

### Шаг 1: Получите ключи

- ✅ Anthropic API key
- ✅ Stability AI key
- ✅ Telegram Bot Token
- ✅ Telegram Chat ID

### Шаг 2: Настройте Railway

```bash
# 1. Создайте PostgreSQL в Railway
New → Database → PostgreSQL

# 2. Добавьте Variables:
AI_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
STABILITY_AI_KEY=sk-...
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_ADMIN_CHAT_ID=123456789
BOT_USERNAME=gdeVacationBot
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

### Шаг 3: Деплой

Railway автоматически задеплоит после добавления variables.

Следите за логами:
```
✅ Миграции выполнены
✅ Используется Anthropic Claude
✅ Маршруты настроены
```

### Шаг 4: Проверка

```bash
# Health check
curl https://your-app.railway.app/health

# Тестовая генерация
curl -X POST https://your-app.railway.app/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{
    "templateType": "lifehack",
    "topic": "Секреты дешёвых билетов"
  }'
```

### Шаг 5: RSS в Дзене

1. Скопируйте RSS URL: `https://your-app.railway.app/api/v1/rss`
2. Яндекс Дзен → Настройки → RSS → Добавить фид
3. Дзен будет проверять RSS каждые 30 минут

### Шаг 6: Запуск автоматики

Посты будут генерироваться автоматически по расписанию:
- 08:00 MSK
- 12:00 MSK
- 16:00 MSK
- 20:00 MSK

---

## 💰 Итоговая стоимость

### Вариант 1: Claude + Stability AI (Рекомендуется)

```
Railway:        $5/месяц
Claude API:     ~$25-40/месяц (4 поста в день)
Stability AI:   ~$15-20/месяц (изображения)
───────────────────────────────────────
ИТОГО:          ~$45-65/месяц
```

**В 2 раза дешевле OpenAI!**

### Вариант 2: YandexGPT + Kandinsky (бюджет)

```
Railway:        $5/месяц
YandexGPT:      ~500-1000₽/месяц (~$5-10)
Kandinsky:      БЕСПЛАТНО
───────────────────────────────────────
ИТОГО:          ~$10-15/месяц
```

**Самый дешёвый вариант!**

---

## 🔧 Обновление .env файла

Создайте `.env` в корне проекта:

```bash
# AI Provider
AI_PROVIDER=anthropic

# Anthropic
ANTHROPIC_API_KEY=sk-ant-your-key-here
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022

# Images
IMAGE_PROVIDER=stability
STABILITY_AI_KEY=sk-your-key-here

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF
TELEGRAM_ADMIN_CHAT_ID=123456789

# Bot
BOT_USERNAME=gdeVacationBot

# Database (локально)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/zenautomation

# Content
POSTS_PER_DAY=4
MIN_POST_LENGTH=3000
MAX_POST_LENGTH=7000

# Quality
ENABLE_CONTENT_VALIDATION=true
MIN_QUALITY_SCORE=0.7
```

---

## 🚀 Запуск локально

```bash
# 1. Установите PostgreSQL
brew install postgresql
brew services start postgresql
createdb zenautomation

# 2. Создайте .env
cp .env.example .env
nano .env  # добавьте свои ключи

# 3. Соберите проект
make build

# 4. Запустите
make run
```

---

## ❓ FAQ

### OpenAI заблокировал, что делать?

**Используйте Claude!** Он даже лучше для русского языка.

### Где дешевле всего?

**YandexGPT + Kandinsky** - $10-15/месяц

### Как получить карту для оплаты?

- **Wise** (wise.com) - виртуальная карта
- **Payoneer** - для фрилансеров
- **Друзья из Европы** - Revolut

### Яндекс Дзен не работает?

Используйте **RSS метод** - самый простой и надёжный.

### Можно ли без Railway?

Да, можно деплоить на:
- **Heroku** (дороже)
- **DigitalOcean** (нужен VPS)
- **AWS** (сложнее)

---

## 📞 Поддержка

Проблемы? Вопросы?

- 💬 Telegram: @your_username
- 🐛 Issues: [GitHub](https://github.com/KamnevVladimir/zen-automation/issues)

---

**Готово! Теперь у вас есть полностью автоматизированная система публикации постов! 🎉**

