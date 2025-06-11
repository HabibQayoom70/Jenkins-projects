#!/bin/bash

# Define the target file
FILE=".env.docker"  # replace with your actual filename

# Perform replacements
sed -i 's|MONGODB_URI=.*|MONGODB_URI=mongodb://mongo:27017/wanderlust|' "$FILE"
sed -i 's|REDIS_URL=.*|REDIS_URL=redis://redis:6379|' "$FILE"
sed -i 's|FRONTEND_URL=.*|FRONTEND_URL=http://frontend:5173|' "$FILE"
