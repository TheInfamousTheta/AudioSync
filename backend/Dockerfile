FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
# Build C++ modules (like sqlite3/bcrypt) from source to match GLIBC
RUN npm ci --build-from-source
COPY . .
RUN npm run build
# Prune devDependencies
RUN npm prune --production

FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
VOLUME /app/data
EXPOSE 4000
CMD ["node", "dist/server.js"]
