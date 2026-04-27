FROM alpine:3.20

# git is required for `quickstart create` and `init`
RUN apk add --no-cache ca-certificates git

COPY agora /usr/local/bin/agora

ENTRYPOINT ["agora"]
