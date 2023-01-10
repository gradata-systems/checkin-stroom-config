# Introduction

This script queries the [Stroom](https://github.com/gchq/stroom) API to download a configuration ZIP bundle.
The configuration is compared to the contents of a Git repository and any changes are checked in as a commit.

# Prerequisites

1. Private key for issuing `git` commands and a corresponding public key authorised by the target Git server.
1. Existing Git remote, for which the user has push permissions.
1. Stroom user account with the following minimum access attributes:
   1. `Export Configuration` cluster permission.
   1. `Read` access to the top-level `System` node, or at least one sub-item.
1. Valid Stroom API key.

# Usage

## Run as a one-time job

```shell
./scripts/sync-stroom-config.sh
```

## Run on Kubernetes as a `CronJob`

1. Customise `/deploy/k8s/cronjob.yaml`
1. Create `Secret` containing `api-key` and `ssh-key`
1. `kubectl apply -f /deploy/k8s/cronjob.yaml`
