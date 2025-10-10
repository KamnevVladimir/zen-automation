.PHONY: build test run clean deploy docker-build

# Сборка проекта
build:
	swift build

# Сборка в release
build-release:
	swift build -c release

# Запуск тестов
test:
	swift test --enable-test-discovery

# Запуск тестов с xcsift
test-xcsift:
	swift test --enable-test-discovery | xcsift

# Запуск с покрытием
test-coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov report .build/debug/zen-automationPackageTests.xctest/Contents/MacOS/zen-automationPackageTests \
		-instr-profile .build/debug/codecov/default.profdata \
		-ignore-filename-regex ".build|Tests"

# Запуск приложения
run:
	swift run

# Очистка
clean:
	rm -rf .build
	rm -rf Package.resolved

# Docker build
docker-build:
	docker build -t zen-automation .

# Docker run
docker-run:
	docker run -p 8080:8080 --env-file .env zen-automation

# Форматирование кода
format:
	swift-format -i -r Sources/
	swift-format -i -r Tests/

# Линтер
lint:
	swiftlint

# Проверка перед коммитом
pre-commit: test lint
	@echo "✅ Готово к коммиту"

# Локальный деплой (с тестами)
deploy-local: clean build-release test
	@echo "✅ Проект готов к деплою"

# Railway деплой
deploy-railway:
	railway up

# Инициализация проекта
init:
	cp .env.example .env
	@echo "📝 Отредактируйте .env файл и добавьте свои API ключи"

