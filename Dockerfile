FROM nginx:alpine

RUN find /usr/share/nginx/html -mindepth 1 -maxdepth 1 -exec rm -rf {} +

COPY build/web/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]