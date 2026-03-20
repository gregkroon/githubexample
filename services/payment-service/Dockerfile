# Build stage
FROM golang:1.21-alpine@sha256:1a24f8e4c96d7d5e5b1d2d5c7d5e5f5a5b5c5d5e5f5a5b5c5d5e5f5a5b5c5d5e AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o payment-service .

# Runtime stage
FROM alpine:3.19@sha256:1a24f8e4c96d7d5e5b1d2d5c7d5e5f5a5b5c5d5e5f5a5b5c5d5e5f5a5b5c5d5e

# Install ca-certificates for HTTPS calls
RUN apk --no-cache add ca-certificates

# Non-root user
RUN addgroup -g 1001 -S appuser && adduser -S appuser -u 1001

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/payment-service .

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["./payment-service"]
