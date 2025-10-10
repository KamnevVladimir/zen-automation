# 🚀 Деплой в Railway

Пошаговая инструкция по деплою Zen Automation в Railway.

## Предварительные требования

- [x] GitHub репозиторий (git@github.com:KamnevVladimir/zen-automation.git)
- [x] Railway аккаунт (railway.app)
- [ ] OpenAI API ключ
- [ ] Telegram Bot Token (для уведомлений)

## Шаг 1: Подключение GitHub

1. Зайдите на [railway.app](https://railway.app)
2. Нажмите **"New Project"**
3. Выберите **"Deploy from GitHub repo"**
4. Выберите `KamnevVladimir/zen-automation`
5. Railway автоматически обнаружит `Dockerfile`

## Шаг 2: Добавление PostgreSQL

1. В проекте нажмите **"New"**
2. Выберите **"Database" → "PostgreSQL"**
3. Railway автоматически создаст БД и добавит `DATABASE_URL`

## Шаг 3: Настройка Environment Variables

В разделе **Variables** добавьте:

### Обязательные переменные

```bash
# OpenAI
OPENAI_API_KEY=sk-your-api-key-here

# Telegram (для уведомлений)
TELEGRAM_BOT_TOKEN=8494700026:AAHWU3WECRMEJuBovIUJlJQtEPBwA1b7aQw
TELEGRAM_ADMIN_CHAT_ID=your_chat_id

# Database (автоматически добавляется Railway)
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

### Опциональные переменные

```bash
# OpenAI Settings
OPENAI_MODEL=gpt-4-turbo-preview
OPENAI_MAX_TOKENS=4000
OPENAI_TEMPERATURE=0.7

# DALL-E Settings
DALLE_MODEL=dall-e-3
DALLE_SIZE=1792x1024
DALLE_QUALITY=hd

# Content Settings
POSTS_PER_DAY=4
MIN_POST_LENGTH=3000
MAX_POST_LENGTH=7000

# Quality Control
ENABLE_CONTENT_VALIDATION=true
MIN_QUALITY_SCORE=0.7

# Bot Integration
BOT_USERNAME=gdeVacationBot
BOT_DEEP_LINK_BASE=https://t.me/gdeVacationBot?start=

# Logging
LOG_LEVEL=info
```

## Шаг 4: Деплой

1. Railway автоматически начнёт деплой после добавления переменных
2. Процесс занимает ~5-10 минут
3. Следите за логами в разделе **"Deployments"**

## Шаг 5: Проверка работы

После успешного деплоя:

```bash
# Проверка health endpoint
curl https://your-app.railway.app/health

# Проверка API
curl https://your-app.railway.app/

# Метрики
curl https://your-app.railway.app/api/v1/metrics
```

## Шаг 6: Настройка CI/CD (опционально)

Railway автоматически деплоит при push в `main` ветку.

Для настройки GitHub Actions:

1. Создайте Railway API Token:
   - Settings → Tokens → Create Token
   
2. Добавьте в GitHub Secrets:
   - Repository → Settings → Secrets
   - Добавьте `RAILWAY_TOKEN`

3. GitHub Actions автоматически запустится при push

## Проверка OpenAI API ключа

Убедитесь что у вас достаточно средств:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

## Получение Telegram Chat ID

1. Напишите боту `@userinfobot` в Telegram
2. Он вышлет ваш Chat ID
3. Добавьте его в `TELEGRAM_ADMIN_CHAT_ID`

## Мониторинг

### Логи в Railway

```
Deployments → Select deployment → Logs
```

### Метрики Railway

```
Project → Metrics
```

Следите за:
- CPU usage
- Memory usage
- Network traffic
- Request count

## Troubleshooting

### Ошибка "Database connection failed"

Проверьте что:
- PostgreSQL сервис запущен
- `DATABASE_URL` правильно настроен
- Миграции прошли успешно

```bash
# В логах должно быть:
✅ Миграции выполнены
```

### Ошибка "OpenAI API error"

Проверьте:
- API ключ валидный
- Достаточно средств на балансе
- Rate limits не превышены

### Приложение не стартует

1. Проверьте логи деплоя
2. Убедитесь что Docker build прошёл успешно
3. Проверьте что все зависимости установлены

## Стоимость

### Railway

- **Hobby Plan**: $5/месяц
- **Включает**: 500 часов, 100GB трафика
- PostgreSQL включена

### OpenAI API

- **GPT-4 Turbo**: ~$0.28 за пост
- **DALL-E 3**: ~$0.24 за пост
- **4 поста/день**: ~$2-3/день = ~$60-90/месяц

**Итого**: ~$65-95/месяц

## Оптимизация расходов

1. **Используйте GPT-4o-mini** вместо GPT-4 Turbo
2. **Генерируйте 2 картинки** вместо 3
3. **Кешируйте промпты**
4. **Используйте меньший max_tokens**

## Масштабирование

Если нужно больше постов:

1. Увеличьте `POSTS_PER_DAY` (до 8-12)
2. Добавьте больше расписаний в `ScheduleConfig`
3. Увеличьте Railway plan если нужно

## Backup базы данных

Railway автоматически делает backup PostgreSQL.

Ручной backup:

```bash
railway db:backup
```

## Обновление кода

```bash
# Локально
git add .
git commit -m "feat: новая фича"
git push origin main

# Railway автоматически задеплоит
```

## Полезные команды

```bash
# Railway CLI
railway login
railway list
railway logs
railway run bash

# Local testing
make build
make test
make docker-build
make docker-run
```

## Поддержка

- 📧 Email: support@example.com
- 💬 Telegram: @support
- 🐛 Issues: [GitHub Issues](https://github.com/KamnevVladimir/zen-automation/issues)

---

**Готово! 🎉 Ваш бот работает автоматически!**

