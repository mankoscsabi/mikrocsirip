# ── Build stage ─────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm install --silent

COPY . .
RUN npx ng build --configuration production

# ── Runtime stage (nginx) ────────────────────────────────────────
FROM nginx:alpine AS runtime

# Egyedi nginx konfig Angular routing-hoz
COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build /app/dist/mikrocsirip-frontend /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
