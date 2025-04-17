FROM golang:alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o pod-migration-sidecar

FROM alpine

WORKDIR /app

COPY --from=builder /app/pod-migration-sidecar .

ENTRYPOINT ["/app/pod-migration-sidecar"]
