package config

import (
	"os"
	"strconv"
)

type Config struct {
	AppEnv         string
	Port           string
	DatabaseURL    string
	RedisURL       string
	RabbitMQURL    string
	JWTSecret      string
	AllowedOrigins string
	AIServiceURL   string
	S3Endpoint     string
	S3AccessKey    string
	S3SecretKey    string
	S3Bucket       string
	S3Region       string
}


func Load() *Config {
	return &Config{
		AppEnv:         getEnv("APP_ENV", "development"),
		Port:           getEnv("PORT", "8080"),
		DatabaseURL:    getEnv("DATABASE_URL", "postgres://biashara:biashara_secret@localhost:5432/biashara?sslmode=disable"),
		RedisURL:       getEnv("REDIS_URL", "redis://:redis_secret@localhost:6379/0"),
		RabbitMQURL:    getEnv("RABBITMQ_URL", "amqp://biashara:rabbit_secret@localhost:5672/biashara"),
		JWTSecret:      getEnv("JWT_SECRET", "dev_secret_change_in_production"),
		AllowedOrigins: getEnv("ALLOWED_ORIGINS", "http://localhost:3000"),
		AIServiceURL:   getEnv("AI_SERVICE_URL", "http://localhost:8000"),
		S3Endpoint:     getEnv("S3_ENDPOINT", "http://localhost:9000"),
		S3AccessKey:    getEnv("S3_ACCESS_KEY", "minio_access"),
		S3SecretKey:    getEnv("S3_SECRET_KEY", "minio_secret_key"),
		S3Bucket:       getEnv("S3_BUCKET", "biashara-receipts"),
		S3Region:       getEnv("S3_REGION", "us-east-1"),
	}
}


// getEnv checks if an environment variable exists, otherwise falls back to a default value
func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// getEnvInt parses an environment variable string as an integer, falling back on failure or absence
func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}