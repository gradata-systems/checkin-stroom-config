# Introduction

This script queries the [Stroom](https://github.com/gchq/stroom) API to download all configuration. Any changes are committed to the target Git repository.

# Prerequisites

1. Private key for issuing `git` commands and a corresponding public key authorised by the target Git server.
1. Stroom user account with the following minimum permissions:
   1. `Export Configuration` cluster permissions.
   1. `Read` access to the top-level `System` node, or at least one sub-item.
1. Valid Stroom API key.

# Usage

## Running as a one-time job

```shell
./scripts/checkin-stroom-config.sh
```

## Running on Kubernetes as a `CronJob`

1. Customise `/deploy/k8s/cronjob.yaml`
1. `kubectl apply -f /deploy/k8s/cronjob.yaml`
