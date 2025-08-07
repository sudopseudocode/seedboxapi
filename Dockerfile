FROM alpine:3.22.1

RUN apk add curl

COPY wrapper.sh /

ENTRYPOINT ["/wrapper.sh"]
