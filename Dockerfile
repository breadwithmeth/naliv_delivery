# We only need the server stage
FROM nginx:alpine

# Copy the ALREADY BUILT files from your local machine to the container
COPY build/web /usr/share/nginx/html

# Optional: If you have a custom nginx.conf to handle Flutter routing
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]