FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG API_BASE=http://localhost:8000
RUN flutter build web --release --base-href /app/ --dart-define=API_BASE=$API_BASE

FROM nginx:alpine
ARG API_BASE=http://localhost:8000
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html/app
COPY landing /usr/share/nginx/html
RUN rm -rf /usr/share/nginx/html/_tools
RUN sed -i "s|__SALUS_API_BASE__|${API_BASE}|g" /usr/share/nginx/html/index.html
EXPOSE 80
