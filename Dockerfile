FROM alpine:latest

RUN apk add curl

COPY wrapper.sh /

ENTRYPOINT ["/wrapper.sh"]
