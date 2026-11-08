FROM alpine:3.21.3

ARG BUILD_SHA=local

RUN apk add --no-cache nginx=1.26.3-r3 \
    && mkdir -p /usr/share/nginx/html \
    && chown -R nginx:nginx /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

RUN case "$BUILD_SHA" in \
      ''|*[!A-Za-z0-9._-]*) echo "BUILD_SHA must contain only letters, digits, dot, underscore, or hyphen" >&2; exit 1 ;; \
    esac \
    && sed -i "s/__BUILD_SHA__/${BUILD_SHA}/g" /usr/share/nginx/html/index.html \
    && chown nginx:nginx /usr/share/nginx/html/index.html

RUN nginx -t

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
