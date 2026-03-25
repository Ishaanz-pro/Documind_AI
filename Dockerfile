FROM ghcr.io/cirruslabs/flutter:3.41.4 AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --no-wasm-dry-run

FROM node:20-alpine
RUN npm install -g serve
COPY --from=build /app/build/web /app

ENV PORT=10000
EXPOSE 10000
CMD ["sh", "-c", "serve -s /app -l ${PORT}"]
