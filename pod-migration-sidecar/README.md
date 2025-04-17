# Pod Migration Sidecar

A Kubernetes sidecar container that monitors node status during maintenance operations.

## Features

- Monitors node status for drain operations
- Logs node drain events
- Debug mode for local testing

## Usage

### Building the Container

```bash
docker build -t your-org/pod-migration-sidecar:latest .
```

### Pushing to Docker Hub

```bash
docker push your-org/pod-migration-sidecar:latest
```

### Configuration

The sidecar container accepts the following environment variables:

- `NODE_NAME`: The name of the node where the pod is running
- `POD_NAME`: The name of the pod
- `NAMESPACE`: The namespace of the pod

### Debug Mode

For local testing, you can run the sidecar in debug mode:

```bash
go run main.go --debug --kubeconfig=/path/to/kubeconfig --context=my-context --node-name=my-node
```

Debug mode options:
- `--debug`: Enable debug mode
- `--kubeconfig`: Path to kubeconfig file (default: $HOME/.kube/config)
- `--context`: Kubernetes context to use
- `--node-name`: Node name to monitor (optional in debug mode)

### Example Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
spec:
  template:
    spec:
      containers:
      - name: main-app
        image: your-app:latest
      - name: pod-migration
        image: your-org/pod-migration-sidecar:latest
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
```

## Development

### Prerequisites

- Go 1.21 or later
- Docker
- Kubernetes cluster access

### Building

```bash
go build -o pod-migration-sidecar
```

### Testing

```bash
go test ./...
``` 