# Coolify Static Site

## Что мешало работе

- В исходном `web/index.html` был root-зависимый путь к `web_support.js`, который хуже переносится на статический хостинг.
- Для Flutter Web нужен SPA fallback на `index.html`, а конфиг с `=404` ломает обновление страницы и прямые заходы по маршрутам.
- Для web push нужен `firebase-messaging-sw.js` в корне сайта.
- Для FCM в браузере нужен `FIREBASE_WEB_VAPID_KEY` во время сборки.
- `404.html` и `50x.html` в проекте отсутствовали, хотя nginx-конфиг на них ссылался.

## Что должно быть в Coolify

- Publish directory: `build/web`
- Build command:

```bash
flutter build web --release --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY
```

- Сайт должен открываться по HTTPS.

## Правильный nginx конфиг

```nginx
server {    
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location = /firebase-messaging-sw.js {
        try_files $uri =404;
        add_header Cache-Control "no-cache" always;
    }

    location = /flutter_service_worker.js {
        try_files $uri =404;
        add_header Cache-Control "no-cache" always;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        internal;
    }
}
```

## Ограничения

- На Android Chrome web push работает как обычный браузерный push при корректном HTTPS и VAPID.
- На iPhone push для web работает только для PWA, добавленного на домашний экран, на iOS/iPadOS 16.4+.
- Если `FIREBASE_WEB_VAPID_KEY` не передан, приложение не сможет получить web FCM token.