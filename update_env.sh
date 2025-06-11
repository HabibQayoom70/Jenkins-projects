#!/bin/bash

set -e  # Stop on any error

echo "🔄 Setting up project..."

# 1. Replace docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.9'

services:
  mongo:
    image: mongo:latest
    container_name: mongo
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
    networks:
      - app-network

  redis:
    image: redis:7
    container_name: redis
    ports:
      - "6379:6379"
    networks:
      - app-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: backend
    ports:
      - "8089:8080"
    environment:
      - NODE_ENV=development
    depends_on:
      - mongo
      - redis
    networks:
      - app-network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: frontend
    ports:
      - "5173:5173"
    environment:
      - VITE_API_PATH=http://backend:8080
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  mongo-data:

networks:
  app-network:
    driver: bridge
EOF
echo "✅ docker-compose.yml replaced."

# 2. Replace backend/.env file
mkdir -p backend
cat > backend/.env.docker <<EOF
MONGODB_URI=mongodb://mongo:27017/wanderlust
REDIS_URL=redis://redis:6379
PORT=8080
FRONTEND_URL=http://frontend:5173
ACCESS_COOKIE_MAXAGE=120000
ACCESS_TOKEN_EXPIRES_IN=120s
REFRESH_COOKIE_MAXAGE=120000
REFRESH_TOKEN_EXPIRES_IN=120s
JWT_SECRET=70dd8b38486eee723ce2505f6db06f1ee503fde5eb06fc04687191a0ed665f3f98776902d2c89f6b993b1c579a87fedaf584c693a106f7cbf16e8b4e67e9d6df
NODE_ENV=Development
EOF
echo "✅ backend/.env replaced."


# 4. Replace frontend/Dockerfile
mkdir -p frontend
cat > frontend/Dockerfile <<EOF
# Stage 1
FROM node:21 AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2
FROM node:21-slim
WORKDIR /app
COPY --from=frontend-builder /app ./
COPY .env.docker .env.local
EXPOSE 5173
CMD ["npm", "run", "preview", "--", "--host", "--port", "5173"]
EOF
echo "✅ frontend/Dockerfile replaced."

# 5. Update or create frontend/.env.docker
if [ -f frontend/.env.docker ]; then
  sed -i 's|VITE_API_PATH=.*|VITE_API_PATH=http://backend:8080|' frontend/.env.docker
  echo "✅ VITE_API_PATH updated in frontend/.env.docker."
else
  echo "VITE_API_PATH=http://backend:8080" > frontend/.env.docker
  echo "✅ frontend/.env.docker created with VITE_API_PATH."
fi

echo "🎉 All project setup steps completed successfully."
