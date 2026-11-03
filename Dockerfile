# 1) Flutter web client (CanvasKit is bundled instead of loaded from a CDN)
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /src
COPY packages packages
COPY app app
RUN cd app && flutter pub get && flutter build web --release --no-web-resources-cdn

# 2) Dart server, compiled ahead of time
FROM dart:stable AS server
WORKDIR /src
COPY packages packages
COPY server server
RUN mkdir -p /out && cd server && dart pub get && dart compile exe bin/server.dart -o /out/server

# 3) Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=server /out/server /app/server
COPY --from=web /src/app/build/web /app/web
COPY --from=server /src/server/legal /app/legal
ENV APP_ENV=production \
    WEB_DIR=/app/web \
    LEGAL_DIR=/app/legal \
    DATA_FILE=/data/scores.json \
    PORT=8080
VOLUME /data
EXPOSE 8080
CMD ["/app/server"]
