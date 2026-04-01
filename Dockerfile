# We only need the server stage
FROM nginx:alpine

# Copy the ALREADY BUILT files from your local machine to the container
COPY build/web /usr/share/nginx/html

# Use a custom nginx config for SPA routing and to avoid stale service workers.
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]