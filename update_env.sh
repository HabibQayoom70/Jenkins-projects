#!/bin/bash

set -e
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

# 2. Modify backend/.env.docker
if [ -d "backend" ]; then
  cd backend
  if [ -f ".env.docker" ]; then
    sed -i 's|MONGODB_URI=.*|MONGODB_URI=mongodb://mongo:27017/wanderlust|' .env.docker
    sed -i 's|REDIS_URL=.*|REDIS_URL=redis://redis:6379|' .env.docker
    sed -i 's|FRONTEND_URL=.*|FRONTEND_URL=http://frontend:5173|' .env.docker
    echo "✅ Replacements applied to backend/.env.docker."
  else
    echo "⚠️ backend/.env.docker not found."
  fi
  cd ..
else
  echo "❌ backend directory not found!"
  exit 1
fi

# 3. Replace frontend/Dockerfile
if [ -d "frontend" ]; then
  cd frontend
  cat > Dockerfile <<EOF
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

  # 4. Update or create frontend/.env.docker
  if [ -f .env.docker ]; then
    sed -i 's|VITE_API_PATH=.*|VITE_API_PATH=http://backend:8080|' .env.docker
    echo "✅ VITE_API_PATH updated in frontend/.env.docker."
  else
    echo "VITE_API_PATH=http://backend:8080" > .env.docker
    echo "✅ frontend/.env.docker created with VITE_API_PATH."
  fi
  cd ..
else
  echo "❌ frontend directory not found!"
  exit 1
fi

echo "🎉 All project setup steps completed successfully."
