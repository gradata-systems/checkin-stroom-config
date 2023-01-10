# Introduction

This script queries the Stroom API to download all configuration. Any changes are committed to the target Git repository.

# Usage

## Running as a one-time job

```shell
./scripts/checkin-stroom-config.sh
```

## Running on Kubernetes as a `CronJob`

1. Customise `/deploy/k8s/cronjob.yaml`
1. `kubectl apply -f /deploy/k8s/cronjob.yaml`