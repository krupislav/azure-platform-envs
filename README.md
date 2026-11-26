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
| dev | `envs/dev` + `envs/dev/workloads` | `dev.tfstate`, `dev-workloads.tfstate` | `10.23.0.0/16` | Infra and AKS deployed by the pipelines; the app ran on AKS (Nov 26) |
| stage | `envs/stage` | `stage.tfstate` | `10.21.0.0/16` | Later |
| prod | `envs/prod` | `prod.tfstate` | `10.22.0.0/16` | Later |

## Layout

```
modules/env/            the blueprint of one environment's infra (a spoke)
modules/workloads/      the blueprint of one environment's compute (AKS)
envs/dev/               dev's infra values; state dev.tfstate
envs/dev/workloads/     dev's compute values; state dev-workloads.tfstate
app/                    the platform test app (Flask, /health), its test and Dockerfile
k8s/platform-test-app/  how the app runs on AKS (namespace, deployment, service)
.github/workflows/      dev.yml (infra), dev-workloads.yml (AKS), app.yml (image CI)
```

`envs/<env>` holds only values. Every environment runs the same modules, so stage and
prod are copies of the dev folders with their own values.

**Two layers per environment, two lifecycles.** Infra (network, Key Vault) stays.
Workloads (AKS) can be destroyed every night and rebuilt by the pipeline, without touching
the infra or needing any new role: the AKS identities and their roles live in onboarding.

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

## The infra pipelines (dev.yml, dev-workloads.yml)

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

Each pipeline only runs for its own folder (`paths` filter), and each has its own state
file and lock (`concurrency`), so they never block each other.

## The app pipeline (app.yml)

| Event | What happens |
|---|---|
| Pull request | test (pytest), build the image, scan it (Grype, fails on a **critical** vulnerability). No Azure login, nothing pushed. |
| Push to `main` | the same, then log in as `id-github-acr` and push to `acrshared0` |

- The image tag is the **commit SHA**, so one image is promoted dev -> stage -> prod and can
  always be traced back to its code. Never `latest`.
- Only `main` can push: the federated credential's subject is `...:ref:refs/heads/main`.
- Secret `ACR_CLIENT_ID` = the client ID of `id-github-acr` (not the dev identity).

## AKS (dev workloads)

- `aks-dev-cc`: 1 node `Standard_D2s_v7` (the trial's 4-vCPU quota; v5 sizes are not
  allowed in this subscription), Free tier, Kubernetes from Azure's default.
- Nodes in `snet-aks`; pods use **Azure CNI Overlay** (`10.244.0.0/16`), so they don't use
  VNet IPs. Outbound through the load balancer's public IP.
- Control plane = `id-aks-dev`, nodes = `id-aks-kubelet-dev` (AcrPull, so no pull secret).
- Sign-in with Entra ID + Azure RBAC; **local accounts disabled**. Access =
  membership in `sg-aks-dev-admins`.
- OIDC issuer and workload identity are on, for Key Vault access from pods later.

Connect and deploy (from your PC):

```powershell
az aks get-credentials -g rg-dev-cc -n aks-dev-cc
kubelogin convert-kubeconfig -l azurecli
kubectl apply -f k8s/platform-test-app/
kubectl get pods,svc -n platform-test-app
```

The Service (type LoadBalancer) gets a public IP: `http://<EXTERNAL-IP>/health`.
To save credit, destroy the workloads layer when not in use (`terraform destroy` in
`envs/dev/workloads`: must say **1 to destroy**, the cluster only).

## Next

- The app reads a secret from Key Vault through **workload identity** (its own identity,
  federated with the cluster's OIDC issuer)
- App Gateway with WAF in the hub in front of the app; the Service becomes internal
- A destroy button / nightly destroy for the workloads pipeline
- Optional: Argo CD (GitOps) to deploy `k8s/` from Git instead of `kubectl`

## Adding an environment

1. In **azure-platform-lab**: add it to onboarding and apply (RG, identity, roles, groups).
2. Here: copy `envs/dev` to `envs/<env>` and change the values and the state key.
3. Copy the workflow, and create the GitHub environment `<env>` with its reviewers.
