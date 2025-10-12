# ⏰ Настройка Railway Cron Jobs для автоматических постов

## 📋 Быстрая инструкция

### 1. Открой Railway Dashboard
Перейди: https://railway.app/dashboard

### 2. Выбери проект `zen-automation`

### 3. Добавь Cron Jobs

Railway поддерживает Cron Jobs двумя способами:

---

## 🎯 Способ 1: Railway Cron Jobs (встроенные)

⚠️ **Внимание:** Railway больше не поддерживает встроенные Cron Jobs с декабря 2024 года.

**Альтернатива:** Используй внешние сервисы.

---

## 🚀 Способ 2: GitHub Actions (рекомендуется)

Создай файл `.github/workflows/scheduled-posts.yml`:

```yaml
name: Scheduled Posts and Promotion

on:
  schedule:
    # Генерация постов 4 раза в день (UTC время)
    # 8:00 MSK = 5:00 UTC
    - cron: '0 5 * * *'   # 8:00 по Москве
    - cron: '0 9 * * *'   # 12:00 по Москве
    - cron: '0 13 * * *'  # 16:00 по Москве
    - cron: '0 17 * * *'  # 20:00 по Москве
    
    # Промо-активность 5 раз в день (UTC время)
    - cron: '0 6 * * *'   # 9:00 по Москве
    - cron: '0 12 * * *'  # 15:00 по Москве
    - cron: '0 15 * * *'  # 18:00 по Москве
    - cron: '0 18 * * *'  # 21:00 по Москве

  workflow_dispatch: # Ручной запуск

jobs:
  generate-post:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 5 * * *' || github.event.schedule == '0 9 * * *' || github.event.schedule == '0 13 * * *' || github.event.schedule == '0 17 * * *'
    steps:
      - name: Generate and publish post
        run: |
          curl -X POST https://zen-automation-production.up.railway.app/api/v1/generate
          
  promote:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 6 * * *' || github.event.schedule == '0 12 * * *' || github.event.schedule == '0 15 * * *' || github.event.schedule == '0 18 * * *'
    steps:
      - name: Run promotion activity
        run: |
          curl -X POST https://zen-automation-production.up.railway.app/api/v1/promote
```

---

## 🛠️ Способ 3: Cron-job.org (внешний сервис)

### Настройка на cron-job.org:

1. **Регистрация:**
   - Перейди на https://cron-job.org
   - Создай бесплатный аккаунт

2. **Создай задачи:**

**Задача 1: Генерация постов**
```
Title: Zen Automation - Post Generation
URL: https://zen-automation-production.up.railway.app/api/v1/generate
Method: POST
Schedule: 
  - 8:00, 12:00, 16:00, 20:00 (по московскому времени)
  - Cron: 0 8,12,16,20 * * *
```

**Задача 2: Промо-активность**
```
Title: Zen Automation - Promotion
URL: https://zen-automation-production.up.railway.app/api/v1/promote
Method: POST
Schedule:
  - 9:00, 12:00, 15:00, 18:00, 21:00 (по московскому времени)
  - Cron: 0 9,12,15,18,21 * * *
```

---

## 🕐 Способ 4: EasyCron (альтернатива)

### Настройка на easycron.com:

1. **Регистрация:**
   - Перейди на https://www.easycron.com
   - Бесплатный план: 100 задач

2. **Создай Cron Jobs:**

**Для постов:**
```
URL: https://zen-automation-production.up.railway.app/api/v1/generate
Method: POST
Cron Expression: 0 8,12,16,20 * * *
Time Zone: Europe/Moscow
Enabled: Yes
```

**Для промо:**
```
URL: https://zen-automation-production.up.railway.app/api/v1/promote
Method: POST
Cron Expression: 0 9,12,15,18,21 * * *
Time Zone: Europe/Moscow
Enabled: Yes
```

---

## 🐳 Способ 5: Docker-контейнер с cron

Создай файл `Dockerfile.cron`:

```dockerfile
FROM alpine:latest

RUN apk add --no-cache curl dcron

COPY crontab /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
```

Создай файл `crontab`:

```cron
# Генерация постов (UTC время)
0 5,9,13,17 * * * curl -X POST https://zen-automation-production.up.railway.app/api/v1/generate

# Промо-активность (UTC время)  
0 6,9,12,15,18 * * * curl -X POST https://zen-automation-production.up.railway.app/api/v1/promote
```

Запусти на Railway:
```bash
railway up -d cron-service
```

---

## 📊 Мониторинг и отладка

### Проверка работы Cron Jobs:

**Логи Railway:**
```bash
railway logs
```

**Ручной запуск для теста:**
```bash
# Генерация поста
curl -X POST https://zen-automation-production.up.railway.app/api/v1/generate

# Промо-активность
curl -X POST https://zen-automation-production.up.railway.app/api/v1/promote

# Метрики
curl https://zen-automation-production.up.railway.app/api/v1/metrics
```

### Ожидаемые логи:

**Успешная генерация:**
```
✅ Zen Automation сконфигурирован
🤖 Telegram бот готов к работе
📝 Генерируем пост типа: destination
✅ Пост сгенерирован: <UUID>
📸 Генерируем изображение...
✅ Изображение сгенерировано
📤 Публикуем в Telegraph...
✅ Telegraph статья создана: https://telegra.ph/...
📱 Публикуем в Telegram...
✅ Пост опубликован в Telegram
```

**Успешная промо-активность:**
```
🎯 Запуск автоматического взаимодействия с Дзеном
🔍 Ищу посты для комментирования...
📝 Найдено 15 постов для взаимодействия
❓ Найдено 23 вопроса
💬 Отвечаю на вопрос: Сколько стоит виза в Т...
✅ Ответ отправлен успешно
📊 Статистика: 8 комментариев, 3 новых подписчиков
```

---

## ⚡️ Рекомендация: GitHub Actions

**Самый надёжный вариант:**

1. **Создай файл в репозитории:**
   ```bash
   mkdir -p .github/workflows
   touch .github/workflows/scheduled-tasks.yml
   ```

2. **Добавь конфигурацию** (см. выше)

3. **Закоммить и запушь:**
   ```bash
   git add .github/workflows/scheduled-tasks.yml
   git commit -m "Add GitHub Actions for scheduled posts"
   git push origin main
   ```

4. **Проверь в GitHub:**
   - Перейди на https://github.com/KamnevVladimir/zen-automation
   - Вкладка "Actions"
   - Убедись, что workflow активирован

---

## 🎯 Итог

После настройки любого из способов:
- ✅ Посты будут генерироваться автоматически 4 раза в день
- ✅ Промо-активность будет запускаться 5 раз в день
- ✅ Логи будут доступны в Railway
- ✅ Система работает 24/7 без вмешательства

**Начни с первых 5 подписчиков уже на этой неделе! 🚀**
