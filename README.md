# azure-platform-envs

The **environments** of the Azure lab: their infrastructure now, and the workloads that
run in them later. Each environment is deployed by its own GitHub Actions pipeline.

What has to exist *before* an environment can be deployed (its resource group, pipeline
identity, roles, access groups, the hub network and the DNS zones) lives in the platform
repo, **azure-platform-lab**.

> Lab project for AZ-104 / AZ-400 practice. Not a production system.

## Today: dev

| Environment | Folder | State file | Address space | Status |
|---|---|---|---|---|
| dev | `envs/dev` | `dev.tfstate` | `10.23.0.0/16` | Infrastructure deployed by the pipeline |
| stage | `envs/stage` | `stage.tfstate` | `10.21.0.0/16` | Later |
| prod | `envs/prod` | `prod.tfstate` | `10.22.0.0/16` | Later |

## Layout

```
modules/env/        the blueprint of one environment (a spoke)
envs/dev/           calls the module with dev's values; own state file
.github/workflows/  one pipeline per environment (dev.yml)
```

`envs/<env>` holds only values. Every environment runs the same module, so stage and
prod are copies of the dev folder with their own values.

## What the env module creates

In `rg-<env>-cc`, which onboarding created. The module only reads it.

- Spoke VNet `vnet-spoke-<env>-cc` with subnets:
  - `snet-aks` (/22): no NSG of its own, because AKS brings its own
  - `snet-app`, `snet-endpoints`, `snet-ops`: one NSG each
- Peering to the hub, **both directions**. The hub-to-spoke side lives in `rg-hub-cc`
  but belongs to this environment.
- Links from the spoke to the shared private DNS zones (also stored in `rg-hub-cc`)
- Key Vault `kv-platform-<env>-cc`, with two gates:
  - **who**: RBAC only. The access groups and roles come from onboarding.
  - **from where**: public access off, reachable only through a private endpoint in
    `snet-endpoints`. Its DNS record is managed by Azure (DNS zone group).

It reads (never changes) the hub VNet and the DNS zones from the global layer.

## The pipeline

No passwords. GitHub issues a short-lived OIDC token, and Azure trusts it because the
token's subject matches a federated credential on `id-github-<env>`.

| Event | Job | Federated credential | What happens |
|---|---|---|---|
| Pull request to `main` | plan | `fc-pr` | init, fmt check, validate, plan. The result shows in the PR. |
| Push to `main` (= the merge) | apply | `fc-env-<env>` | Waits for approval in the GitHub `<env>` environment, then applies |

Safety rules:
- The `dev` environment needs a reviewer, admins can't bypass it, and only `main` can deploy to it.
- `concurrency: tfstate-<env>`: never two runs on the same state at once.
- The pipeline has Contributor on its own resource group only. It can't change its own
  permissions.
- The IDs it needs are stored as repo secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID`), so they don't appear in the public logs.

## Next: workloads

The workloads go into this repo too, on top of the environment's infrastructure:

- The app: a small API, built and pushed to the shared registry `acrshared0` by CI
- AKS, in its own layer and state file, so compute can be destroyed every night without
  touching the network or Key Vault
- The app reads its secrets from Key Vault through workload identity
- Later: App Gateway with WAF in front of the app

## Adding an environment

1. In **azure-platform-lab**: add it to onboarding and apply (RG, identity, roles, groups).
2. Here: copy `envs/dev` to `envs/<env>` and change the values and the state key.
3. Copy the workflow, and create the GitHub environment `<env>` with its reviewers.
