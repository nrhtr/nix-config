# syntax=docker/dockerfile:1
# Build locally: fly deploy --local-only --ssh
FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git openssh-client
RUN mkdir -p ~/.ssh && ssh-keyscan git.jenga.xyz >> ~/.ssh/known_hosts
WORKDIR /build
ARG URBIT_SH_REF=main
RUN --mount=type=ssh \
    git clone ssh://git@git.jenga.xyz/~/urbit.sh.git . && \
    git checkout ${URBIT_SH_REF}
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o ssh-server .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates wireguard-tools iproute2
WORKDIR /app
COPY --from=builder /build/ssh-server .
COPY wg0.conf.template /etc/wireguard/wg0.conf.template
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
EXPOSE 2222
ENTRYPOINT ["./entrypoint.sh"]
