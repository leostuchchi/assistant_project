-- ============================================
-- ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ PERSONAL ASSISTANT
-- ============================================

-- Отключаем транзакции для CREATE DATABASE
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

-- Создаем расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ============================================
-- 1. БАЗОВАЯ ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    
    -- Идентификаторы (только хэши)
    telegram_id BIGINT UNIQUE,
    phone_hash VARCHAR(128) UNIQUE,
    email_hash VARCHAR(128) UNIQUE,
    
    -- Базовый статус
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_premium BOOLEAN DEFAULT FALSE,
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_telegram ON users(telegram_id);
CREATE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_activity ON users(last_activity_at DESC);

-- ============================================
-- 2. ПРОФИЛИ ПОЛЬЗОВАТЕЛЕЙ
-- ============================================

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Личные данные
    full_name VARCHAR(255),
    username VARCHAR(100),
    language_code VARCHAR(10) DEFAULT 'ru',
    
    -- Данные для расчетов
    birth_date DATE NOT NULL,
    birth_time TIME NOT NULL,
    birth_city VARCHAR(100) NOT NULL,
    birth_country VARCHAR(100) DEFAULT 'Russia',
    timezone VARCHAR(50) DEFAULT 'Europe/Moscow',
    
    -- Профессиональные данные
    profession VARCHAR(100),
    job_position VARCHAR(100),
    current_city VARCHAR(100),
    
    CONSTRAINT valid_birth_date CHECK (
        birth_date >= '1900-01-01' AND 
        birth_date <= CURRENT_DATE - INTERVAL '1 year'
    )
);

CREATE INDEX IF NOT EXISTS idx_profiles_birth_date ON user_profiles(birth_date);
CREATE INDEX IF NOT EXISTS idx_profiles_city ON user_profiles(birth_city);

-- ============================================
-- 3. СЕССИИ АВТОРИЗАЦИИ
-- ============================================

CREATE TABLE IF NOT EXISTS auth_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Безопасное хранение токенов
    session_token_hash VARCHAR(128) NOT NULL UNIQUE,
    refresh_token_hash VARCHAR(128),
    
    -- Метод авторизации
    auth_method VARCHAR(20) NOT NULL,
    
    -- Информация о сессии
    device_type VARCHAR(50),
    device_info JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Время
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON auth_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON auth_sessions(session_token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON auth_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON auth_sessions(is_active);

-- ============================================
-- 4. НАТАЛЬНЫЕ КАРТЫ
-- ============================================

CREATE TABLE IF NOT EXISTS natal_charts (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные данные расчета
    calculation_datetime TIMESTAMPTZ NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    altitude INTEGER,
    timezone VARCHAR(50) NOT NULL,
    
    -- Астрологические данные
    planets JSONB NOT NULL DEFAULT '{}',
    houses JSONB NOT NULL DEFAULT '{}',
    angles JSONB NOT NULL DEFAULT '{}',
    aspects JSONB NOT NULL DEFAULT '{}',
    placements JSONB NOT NULL DEFAULT '{}',
    
    -- ML-признаки
    ml_features JSONB NOT NULL DEFAULT '{}',
    element_balance JSONB NOT NULL DEFAULT '{}',
    sign_distribution JSONB NOT NULL DEFAULT '{}',
    
    -- Метаданные
    calculation_jd DECIMAL(12,6) NOT NULL,
    house_system VARCHAR(20) DEFAULT 'Placidus',
    ephemeris_version VARCHAR(20) DEFAULT 'DE441',
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_natal_planets_gin ON natal_charts USING GIN(planets);
CREATE INDEX IF NOT EXISTS idx_natal_aspects_gin ON natal_charts USING GIN(aspects);
CREATE INDEX IF NOT EXISTS idx_natal_features_gin ON natal_charts USING GIN(ml_features);

-- ============================================
-- 5. ПСИХОМАТРИЦЫ
-- ============================================

CREATE TABLE IF NOT EXISTS psyho_matrices (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные числа
    first_number INTEGER NOT NULL,
    second_number INTEGER NOT NULL,
    third_number INTEGER NOT NULL,
    fourth_number INTEGER NOT NULL,
    
    -- Матрица Пифагора
    matrix_digits JSONB NOT NULL DEFAULT '{}',
    characteristics JSONB NOT NULL DEFAULT '{}',
    
    -- Дополнительный анализ
    energy_level VARCHAR(50),
    life_purpose TEXT,
    talents JSONB NOT NULL DEFAULT '[]',
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matrices_digits_gin ON psyho_matrices USING GIN(matrix_digits);
CREATE INDEX IF NOT EXISTS idx_matrices_created ON psyho_matrices(created_at);

-- ============================================
-- 6. БИОРИТМЫ (партиционирование будет настроено позже)
-- ============================================

CREATE TABLE IF NOT EXISTS biorhythms (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Основные циклы
    physical_cycle SMALLINT NOT NULL,
    emotional_cycle SMALLINT NOT NULL,
    intellectual_cycle SMALLINT NOT NULL,
    intuitive_cycle SMALLINT NOT NULL,
    
    -- Проценты
    physical_percentage SMALLINT NOT NULL,
    emotional_percentage SMALLINT NOT NULL,
    intellectual_percentage SMALLINT NOT NULL,
    intuitive_percentage SMALLINT NOT NULL,
    
    -- Метаданные циклов
    physical_phase VARCHAR(20),
    emotional_phase VARCHAR(20),
    intellectual_phase VARCHAR(20),
    intuitive_phase VARCHAR(20),
    
    -- Общая энергия
    overall_energy SMALLINT NOT NULL,
    overall_energy_percentage SMALLINT NOT NULL,
    overall_energy_level VARCHAR(20),
    
    -- Дополнительные данные
    days_lived INTEGER NOT NULL,
    recommendations JSONB NOT NULL DEFAULT '[]',
    critical_days JSONB NOT NULL DEFAULT '[]',
    peak_days JSONB NOT NULL DEFAULT '[]',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, calculation_date)
);

CREATE INDEX IF NOT EXISTS idx_biorhythms_user_date ON biorhythms(user_id, calculation_date);
CREATE INDEX IF NOT EXISTS idx_biorhythms_date ON biorhythms(calculation_date);

-- ============================================
-- 7. MAGIC PROFILES
-- ============================================

CREATE TABLE IF NOT EXISTS magic_profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные разделы профиля
    ethical_framework JSONB NOT NULL DEFAULT '{}',
    social_predispositions JSONB NOT NULL DEFAULT '{}',
    emotional_architecture JSONB NOT NULL DEFAULT '{}',
    intellectual_traits JSONB NOT NULL DEFAULT '{}',
    willpower_profile JSONB NOT NULL DEFAULT '{}',
    creative_intuitive JSONB NOT NULL DEFAULT '{}',
    psychological_blueprint JSONB NOT NULL DEFAULT '{}',
    
    -- ML-данные
    ml_features JSONB NOT NULL DEFAULT '{}',
    feature_vector REAL[] NOT NULL DEFAULT '{}',
    profile_version VARCHAR(20) DEFAULT '1.0',
    
    -- Метаданные
    calculation_metadata JSONB NOT NULL DEFAULT '{}',
    data_sources JSONB NOT NULL DEFAULT '[]',
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_magic_ethical_gin ON magic_profiles USING GIN(ethical_framework);
CREATE INDEX IF NOT EXISTS idx_magic_features_gin ON magic_profiles USING GIN(ml_features);

-- ============================================
-- 8. ОПТИМАЛЬНЫЕ АКТИВНОСТИ
-- ============================================

CREATE TABLE IF NOT EXISTS optimal_activities (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Оптимальные активности
    activities SMALLINT[] NOT NULL DEFAULT '{}',
    activity_scores REAL[] NOT NULL DEFAULT '{}',
    
    -- ML-данные
    ml_features JSONB NOT NULL DEFAULT '{}',
    feature_vector REAL[] NOT NULL DEFAULT '{}',
    
    -- Метаданные
    energy_level REAL,
    recommendations_ready BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (user_id, calculation_date)
);

CREATE INDEX IF NOT EXISTS idx_activities_user_date ON optimal_activities(user_id, calculation_date);
CREATE INDEX IF NOT EXISTS idx_activities_date ON optimal_activities(calculation_date);

-- ============================================
-- 9. РЕКОМЕНДАЦИИ
-- ============================================

CREATE TABLE IF NOT EXISTS recommendations (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recommendation_date DATE NOT NULL,
    
    -- Содержимое
    recommendation_text TEXT NOT NULL,
    short_summary TEXT,
    activities_list JSONB NOT NULL DEFAULT '[]',
    
    -- Данные для генерации
    based_on JSONB NOT NULL DEFAULT '{}',
    source_types TEXT[] NOT NULL DEFAULT '{}',
    
    -- Качество
    confidence_score REAL DEFAULT 0.5,
    energy_level VARCHAR(20),
    priority_level VARCHAR(20) DEFAULT 'medium',
    
    -- Кэширование
    cache_key VARCHAR(255) UNIQUE,
    cache_expires_at TIMESTAMPTZ,
    
    -- FTS
    search_vector TSVECTOR,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, recommendation_date)
);

CREATE INDEX IF NOT EXISTS idx_recommendations_user_date ON recommendations(user_id, recommendation_date);
CREATE INDEX IF NOT EXISTS idx_recommendations_cache ON recommendations(cache_key);
CREATE INDEX IF NOT EXISTS idx_recommendations_search_gin ON recommendations USING GIN(search_vector);

-- ============================================
-- 10. СИСТЕМНЫЙ АУДИТ
-- ============================================

CREATE TABLE IF NOT EXISTS system_audit_log (
    id BIGSERIAL PRIMARY KEY,
    
    -- Действие
    action_type VARCHAR(50) NOT NULL,
    action_name VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    
    -- Пользователь
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    user_ip INET,
    user_agent TEXT,
    
    -- Данные
    request_data JSONB,
    response_data JSONB,
    error_details TEXT,
    
    -- Статус
    status_code INTEGER,
    success BOOLEAN DEFAULT TRUE,
    
    -- Производительность
    duration_ms INTEGER,
    
    -- Метаданные
    service_name VARCHAR(50) NOT NULL,
    endpoint VARCHAR(255),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON system_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON system_audit_log(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_date ON system_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_service ON system_audit_log(service_name);

-- ============================================
-- 11. ТРИГГЕРЫ И ФУНКЦИИ
-- ============================================

-- Функция обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для обновления updated_at
CREATE TRIGGER IF NOT EXISTS update_users_updated_at 
BEFORE UPDATE ON users 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_natal_charts_updated_at 
BEFORE UPDATE ON natal_charts 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_magic_profiles_updated_at 
BEFORE UPDATE ON magic_profiles 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_optimal_activities_updated_at 
BEFORE UPDATE ON optimal_activities 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_recommendations_updated_at 
BEFORE UPDATE ON recommendations 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для FTS
CREATE OR REPLACE FUNCTION recommendations_tsvector_trigger()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('russian', COALESCE(NEW.recommendation_text, '')), 'A') ||
        setweight(to_tsvector('russian', COALESCE(NEW.short_summary, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS recommendations_search_vector_update 
BEFORE INSERT OR UPDATE ON recommendations 
FOR EACH ROW EXECUTE FUNCTION recommendations_tsvector_trigger();

-- Функция очистки старых данных
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
BEGIN
    DELETE FROM auth_sessions WHERE expires_at < NOW() - INTERVAL '30 days';
    RAISE NOTICE 'Cleaned old sessions';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 12. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ БД И ПРАВ
-- ============================================

DO $$
BEGIN
    -- Создаем роль приложения
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_app') THEN
        CREATE ROLE personal_assistant_app WITH LOGIN PASSWORD 'App_Password_123!';
    END IF;
    
    -- Создаем readonly роль
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_readonly') THEN
        CREATE ROLE personal_assistant_readonly WITH LOGIN PASSWORD 'Readonly_Pass_456!';
    END IF;
    
    -- Даем права
    GRANT CONNECT ON DATABASE personal_assistant TO personal_assistant_app, personal_assistant_readonly;
    GRANT USAGE ON SCHEMA public TO personal_assistant_app, personal_assistant_readonly;
    
    -- Права на таблицы
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public 
    TO personal_assistant_app;
    
    GRANT SELECT ON ALL TABLES IN SCHEMA public 
    TO personal_assistant_readonly;
    
    -- Права на последовательности
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public 
    TO personal_assistant_app;
    
    RAISE NOTICE 'Database roles and permissions created successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating roles: %', SQLERRM;
END
$$;

-- ============================================
-- 13. СОЗДАНИЕ ПРЕДСТАВЛЕНИЙ ДЛЯ АНАЛИТИКИ
-- ============================================

CREATE OR REPLACE VIEW user_monitoring AS
SELECT 
    u.id,
    u.telegram_id,
    u.is_active,
    u.is_premium,
    u.created_at,
    u.last_activity_at,
    up.full_name,
    up.birth_date,
    (SELECT COUNT(*) FROM recommendations r WHERE r.user_id = u.id) as rec_count
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id;

CREATE OR REPLACE VIEW calculation_monitoring AS
SELECT 
    'natal_charts' as type,
    COUNT(*) as count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM natal_charts
UNION ALL
SELECT 
    'biorhythms',
    COUNT(*),
    MIN(created_at),
    MAX(created_at)
FROM biorhythms
UNION ALL
SELECT 
    'recommendations',
    COUNT(*),
    MIN(created_at),
    MAX(created_at)
FROM recommendations;




-- Вьюха для получения полной информации о пользователе
CREATE VIEW user_complete_info AS
SELECT 
    u.id,
    u.telegram_id,
    u.last_activity_at,
    up.full_name,
    up.username,
    up.birth_date,
    up.birth_city,
    up.current_city,
    up.profession,
    COUNT(DISTINCT r.id) as total_recommendations,
    MAX(r.recommendation_date) as last_recommendation_date
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN recommendations r ON u.id = r.user_id
GROUP BY u.id, up.full_name, up.username, up.birth_date, up.birth_city, up.current_city, up.profession;

-- Вьюха для ежедневной сводки по биоритмам
CREATE VIEW daily_biorhythm_summary AS
SELECT 
    b.user_id,
    b.calculation_date,
    b.overall_energy_level,
    b.overall_energy_percentage,
    b.critical_days,
    b.peak_days,
    oa.energy_level as activity_energy_level,
    oa.recommendations_ready
FROM biorhythms b
LEFT JOIN optimal_activities oa 
    ON b.user_id = oa.user_id 
    AND b.calculation_date = oa.calculation_date
WHERE b.calculation_date = CURRENT_DATE;

-- ============================================
-- КОММЕНТАРИИ К ТАБЛИЦАМ
-- ============================================
COMMENT ON TABLE users IS 'Основная таблица пользователей системы';
COMMENT ON TABLE auth_sessions IS 'Сессии аутентификации пользователей';
COMMENT ON TABLE biorhythms IS 'Расчеты биоритмов пользователей';
COMMENT ON TABLE magic_profiles IS 'Психологические и эзотерические профили';
COMMENT ON TABLE natal_charts IS 'Натальные астрологические карты';
COMMENT ON TABLE optimal_activities IS 'Рекомендации оптимальных активностей';
COMMENT ON TABLE psyho_matrices IS 'Нумерологические психоматрицы';
COMMENT ON TABLE recommendations IS 'Итоговые рекомендации для пользователей';
COMMENT ON TABLE system_audit IS 'Логирование действий в системе';
COMMENT ON TABLE user_profiles IS 'Дополнительная информация о пользователях';

COMMENT ON COLUMN users.phone_hash IS 'SHA512 хэш номера телефона для анонимизации';
COMMENT ON COLUMN users.email_hash IS 'SHA512 хэш email для анонимизации';
COMMENT ON COLUMN auth_sessions.device_info IS 'JSON с информацией об устройстве (модель, ОС, браузер)';
COMMENT ON COLUMN magic_profiles.feature_vector IS 'Бинарный вектор признаков для ML моделей';
COMMENT ON COLUMN recommendations.search_vector IS 'Вектор для полнотекстового поиска по рекомендациям';

-- ============================================
-- 14. ЗАВЕРШЕНИЕ ИНИЦИАЛИЗАЦИИ
-- ============================================

-- Собираем статистику
ANALYZE;

-- Логируем успешное завершение
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'DATABASE INITIALIZATION COMPLETE';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Tables created: 11';
    RAISE NOTICE 'Indexes created: 35';
    RAISE NOTICE 'Views created: 2';
    RAISE NOTICE 'Functions created: 3';
    RAISE NOTICE '============================================';
END
$$;
