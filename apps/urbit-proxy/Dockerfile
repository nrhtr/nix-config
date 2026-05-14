# Build with: ./deploy.sh (copies npins-pinned source into context)
FROM golang:1.25-alpine AS builder
WORKDIR /build
COPY _src/ .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o ssh-server ./cmd/proxy

FROM alpine:3.21
RUN apk add --no-cache ca-certificates wireguard-tools iproute2
WORKDIR /app
COPY --from=builder /build/ssh-server .
COPY wg0.conf.template /etc/wireguard/wg0.conf.template
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
EXPOSE 2222
ENTRYPOINT ["./entrypoint.sh"]
