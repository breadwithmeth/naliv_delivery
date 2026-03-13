# Stage 1: Build the Flutter app
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Copy the source code
COPY . .

# Fetch dependencies and build for web
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app with Nginx
FROM nginx:alpine
# Copy the built static files to Nginx's serving directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Optional but recommended: Copy custom Nginx config for routing
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]