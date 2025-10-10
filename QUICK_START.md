# ⚡ Быстрый старт Zen Automation

## 🎯 Что делать дальше (по порядку)

### 1️⃣ Получить API ключи (15 минут)

**Anthropic Claude (Рекомендуется!)** 🔥
1. Зайдите на [console.anthropic.com](https://console.anthropic.com/)
2. Sign Up
3. **API Keys** → **Create Key**
4. Скопируйте `sk-ant-...`
5. **Billing** → Пополните $5

**Где взять карту для оплаты:**
- [wise.com](https://wise.com) - виртуальная карта (проще всего)
- [payoneer.com](https://payoneer.com) - карта для фрилансеров
- Друзья из Европы с Revolut

**Stability AI (для картинок)** 🖼️
1. Зайдите на [platform.stability.ai](https://platform.stability.ai/)
2. Sign Up
3. **API Keys** → **Create Key**
4. Скопируйте ключ
5. Купите кредиты $10

**Telegram Bot** 🤖
1. Найдите [@BotFather](https://t.me/BotFather)
2. `/newbot`
3. Скопируйте токен
4. Напишите [@userinfobot](https://t.me/userinfobot) для Chat ID

---

### 2️⃣ Настроить Railway (10 минут)

1. Зайдите на [railway.app](https://railway.app/)
2. Sign Up через GitHub
3. **New Project** → **Deploy from GitHub**
4. Выберите `KamnevVladimir/zen-automation`

**Добавить PostgreSQL:**
- **New** → **Database** → **PostgreSQL**

**Добавить Variables:**
```bash
AI_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
IMAGE_PROVIDER=stability
STABILITY_AI_KEY=sk-...
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_ADMIN_CHAT_ID=123456789
BOT_USERNAME=gdeVacationBot
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

Railway автоматически задеплоит (~5 минут).

---

### 3️⃣ Проверить работу (5 минут)

```bash
# Health check
curl https://your-app.railway.app/health
# Ответ: 200 OK

# API info
curl https://your-app.railway.app/
# Ответ: {"service":"zen-automation","status":"running"}

# Тестовая генерация
curl -X POST https://your-app.railway.app/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{"templateType":"lifehack","topic":"Секреты дешёвых билетов"}'
# Ответ: JSON с постом
```

---

### 4️⃣ Подключить к Яндекс Дзен (5 минут)

**Метод 1: RSS (Самый простой!)** ✅

1. Зайдите на [zen.yandex.ru](https://zen.yandex.ru/)
2. **Настройки канала** → **RSS**
3. Включите импорт
4. Добавьте URL: `https://your-app.railway.app/api/v1/rss`
5. Готово! Дзен будет проверять RSS каждые 30 минут

**Метод 2: Telegram → Дзен**

1. Создайте Telegram канал
2. **Настройки канала Дзен** → **Кросспостинг** → **Telegram**
3. Модифицируйте код для публикации в Telegram

---

### 5️⃣ Запустить автоматику ✨

**Посты будут генерироваться автоматически:**

- 🌅 **08:00 MSK** - Weekend Post (выходные)
- ☀️ **12:00 MSK** - Budget Post (бюджеты)
- 🌆 **16:00 MSK** - Lifehack Post (лайфхаки)
- 🌃 **20:00 MSK** - Trending Post (тренды)

**Никаких дополнительных действий не нужно!**

---

## 💰 Стоимость

**С Claude + Stability AI:**
```
Railway:        $5/месяц
Claude API:     ~$30/месяц
Stability AI:   ~$15/месяц
──────────────────────────
ИТОГО:          ~$50/месяц
```

**120 постов в месяц = $0.42 за пост**

---

## 🆘 Проблемы?

### OpenAI заблокировал
✅ **Решение:** Используйте Claude (даже лучше!)

### Нет карты для оплаты
✅ **Решение:** [wise.com](https://wise.com) - виртуальная карта

### Дзен не импортирует RSS
✅ **Решение:** 
1. Проверьте что RSS работает: `https://your-app.railway.app/api/v1/rss`
2. Подождите 30-60 минут
3. Используйте Telegram → Дзен метод

### Хочу дешевле
✅ **Решение:** YandexGPT + Kandinsky = ~$10-15/месяц
```bash
AI_PROVIDER=yandexgpt
IMAGE_PROVIDER=kandinsky
```

---

## 📚 Полная документация

- **SETUP_GUIDE.md** - подробные инструкции по всем ключам
- **DEPLOYMENT.md** - детали по Railway
- **README.md** - техническая документация
- **STATUS.md** - что уже сделано

---

## 🎉 Всё готово!

После выполнения этих шагов ваша система будет:
- ✅ Генерировать 4 поста в день автоматически
- ✅ Создавать уникальные изображения
- ✅ Публиковать в Яндекс Дзен через RSS
- ✅ Отправлять уведомления в Telegram

**Просто расслабьтесь и смотрите как боты работают! 🚀**

---

## ⏱️ Время на настройку

- Получение ключей: **15 мин**
- Настройка Railway: **10 мин**
- Проверка: **5 мин**
- Подключение Дзен: **5 мин**

**Итого: ~35 минут** ⚡

---

💬 Вопросы? Смотри **SETUP_GUIDE.md** или Issues на GitHub!

