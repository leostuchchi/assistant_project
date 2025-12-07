# ============================================
# PERSONAL ASSISTANT ECOSYSTEM - ROOT MAKEFILE
# ============================================

.PHONY: help up down restart logs psql redis ollama status clean setup init validate

help:
	@echo "Personal Assistant Ecosystem Management"
	@echo ""
	@echo "Usage:"
	@echo "  make up         - Start core services (postgres, redis, ollama)"
	@echo "  make up-all     - Start all services with admin tools"
	@echo "  make down       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - Show logs for all services"
	@echo "  make psql       - Connect to PostgreSQL"
	@echo "  make redis      - Connect to Redis"
	@echo "  make ollama     - Pull Ollama model"
	@echo "  make status     - Show service status"
	@echo "  make clean      - Remove all containers and volumes"
	@echo "  make setup      - Full setup (init + pull models)"
	@echo "  make init       - Initialize database only"
	@echo "  make validate   - Validate SQL scripts"
	@echo "  make backup     - Create database backup"
	@echo ""
	@echo "Profiles:"
	@echo "  docker-compose --profile admin up -d    # With admin tools"
	@echo "  docker-compose --profile init up -d     # Run initialization"

# Создание необходимых директорий
create-dirs:
	@mkdir -p data/postgres data/redis data/ollama data/backups
	@mkdir -p models backup_scripts
	@echo "✅ Directories created"

# Запуск базовых сервисов
up: create-dirs
	@echo "🚀 Starting core services..."
	docker-compose up -d postgres redis ollama
	@sleep 5
	@make status

# Запуск всех сервисов с админкой
up-all: create-dirs
	@echo "🚀 Starting all services with admin tools..."
	docker-compose --profile admin up -d
	@sleep 5
	@make status

# Остановка сервисов
down:
	@echo "🛑 Stopping services..."
	docker-compose down
	@echo "✅ Services stopped"

# Перезапуск
restart: down up
	@echo "🔄 Services restarted"

# Просмотр логов
logs:
	@echo "📋 Showing logs (Ctrl+C to exit)..."
	docker-compose logs -f --tail=100

# Подключение к PostgreSQL
psql:
	@echo "📊 Connecting to PostgreSQL..."
	docker-compose exec postgres psql -U pa_admin -d personal_assistant

# Подключение к Redis
redis:
	@echo "🔴 Connecting to Redis..."
	docker-compose exec redis redis-cli

# Загрузка модели Ollama
ollama:
	@echo "🤖 Pulling Ollama model (mistral)..."
	docker-compose exec ollama ollama pull mistral
	@echo "✅ Model downloaded"

# Статус сервисов
status:
	@echo "📊 Service Status:"
	@docker-compose ps --all
	@echo ""
	@echo "🌐 Network Info:"
	@docker network inspect personal-assistant-network --format='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{printf "\n"}}{{end}}' 2>/dev/null || echo "Network not found"
	@echo ""
	@echo "💾 Volume Usage:"
	@docker system df -v | grep -A5 "VOLUME NAME"

# Очистка
clean:
	@echo "🧹 Cleaning up..."
	docker-compose down -v --rmi all
	@echo "✅ All containers, volumes, and images removed"

# Полная настройка
setup: create-dirs
	@echo "⚙️  Starting full setup..."
	@make init
	@make ollama
	@echo "🎉 Setup complete! Run 'make up' to start services"

# Инициализация БД
init: create-dirs
	@echo "🗄️  Initializing database..."
	@cd init_scripts && make validate
	docker-compose --profile init up init-db --build --abort-on-container-exit
	@echo "✅ Database initialized"

# Валидация SQL скриптов
validate:
	@echo "🔍 Validating SQL scripts..."
	@cd init_scripts && make validate
	@echo "✅ All SQL scripts are valid"

# Создание бэкапа
backup:
	@echo "💾 Creating backup..."
	@if [ ! -d "backup_scripts" ]; then \
		echo "Creating backup_scripts directory..."; \
		mkdir -p backup_scripts; \
		cp backup.sh.example backup_scripts/backup.sh 2>/dev/null || true; \
	fi
	@echo "✅ Backup script ready. Run manually: ./backup_scripts/backup.sh"

# Просмотр конфигурации PostgreSQL
show-config:
	@echo "📋 PostgreSQL Configuration:"
	@docker-compose exec postgres cat /etc/postgresql/postgresql.conf | head -50

# Проверка здоровья сервисов
health:
	@echo "🏥 Health Checks:"
	@docker-compose ps --filter "status=running" --format "table {{.Names}}\t{{.Status}}"
	@echo ""
	@echo "🔍 Detailed:"
	@docker-compose exec postgres pg_isready -U pa_admin && echo "✅ PostgreSQL: Healthy" || echo "❌ PostgreSQL: Unhealthy"
	@docker-compose exec redis redis-cli ping | grep -q PONG && echo "✅ Redis: Healthy" || echo "❌ Redis: Unhealthy"
	@curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama: Healthy" || echo "❌ Ollama: Unhealthy"
