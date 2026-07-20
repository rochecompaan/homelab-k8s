# Matrix CPU and K3s Alert Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Matrix PostgreSQL burst CPU capacity and remove kube-prometheus-stack rules and monitors that cannot work with this K3s topology.

**Architecture:** Configure the existing ArgoCD Application Helm values only. Matrix receives explicit PostgreSQL resources with a `500m` CPU limit, while kube-prometheus-stack disables its standalone controller-manager, scheduler, and kube-proxy integrations at their component gates.

**Tech Stack:** ArgoCD Application manifests, Helm, YAML, Matrix chart `2.9.16`, kube-prometheus-stack `79.12.0`, Kustomize

## Global Constraints

- All delivery is GitOps-only; do not run cluster mutation commands.
- Keep Matrix PostgreSQL at a `100m` CPU request and `500m` CPU limit.
- Preserve PostgreSQL memory at `128Mi` request / `192Mi` limit.
- Preserve PostgreSQL ephemeral storage at `50Mi` request / `2Gi` limit.
- Disable `kubeControllerManager`, `kubeProxy`, and `kubeScheduler` as complete kube-prometheus-stack components.
- Do not modify `argocd/homelab/grafana-dashboards/alert-log-errors.yaml`.
- Do not add automated tests for these static Helm values; use direct YAML, Helm rendering, and Kustomize verification.
- Do not run `nix flake check`; this repository revision has no `flake.nix`.

---

### Task 1: Increase Matrix PostgreSQL burst CPU capacity

**Files:**
- Modify: `argocd/base/matrix/app.yaml:58-63`

**Interfaces:**
- Consumes: Matrix chart `2.9.16` values at `.spec.source.helm.valuesObject.postgresql.primary`.
- Produces: Explicit PostgreSQL `resources` passed to the chart's PostgreSQL StatefulSet.

- [ ] **Step 1: Add explicit PostgreSQL resources**

Under `postgresql.primary`, retain `persistence` and add this sibling mapping:

```yaml
            resources:
              limits:
                cpu: 500m
                ephemeral-storage: 2Gi
                memory: 192Mi
              requests:
                cpu: 100m
                ephemeral-storage: 50Mi
                memory: 128Mi
```

- [ ] **Step 2: Parse the Application and assert its values**

Run:

```bash
yq -e '
  .spec.source.helm.valuesObject.postgresql.primary.resources == {
    "limits": {
      "cpu": "500m",
      "ephemeral-storage": "2Gi",
      "memory": "192Mi"
    },
    "requests": {
      "cpu": "100m",
      "ephemeral-storage": "50Mi",
      "memory": "128Mi"
    }
  }
' argocd/base/matrix/app.yaml
```

Expected: `true` and exit status 0.

- [ ] **Step 3: Render the pinned Matrix chart and verify the container resources**

Run:

```bash
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
yq '.spec.source.helm.valuesObject' argocd/base/matrix/app.yaml > "$tmpdir/values.yaml"
helm template matrix matrix \
  --repo https://remram44.github.io/matrix-helm \
  --version 2.9.16 \
  --namespace matrix \
  -f "$tmpdir/values.yaml" \
  > "$tmpdir/rendered.yaml"
yq -e '
  select(.kind == "StatefulSet")
  | .spec.template.spec.containers[]
  | select(.name == "postgresql")
  | .resources == {
      "limits": {
        "cpu": "500m",
        "ephemeral-storage": "2Gi",
        "memory": "192Mi"
      },
      "requests": {
        "cpu": "100m",
        "ephemeral-storage": "50Mi",
        "memory": "128Mi"
      }
    }
' "$tmpdir/rendered.yaml"
```

Expected: `true` and exit status 0 for the PostgreSQL container.

- [ ] **Step 4: Check the focused diff**

Run:

```bash
git diff --check
git diff -- argocd/base/matrix/app.yaml
```

Expected: no whitespace errors; only the explicit resource mapping is added.

- [ ] **Step 5: Commit the Matrix resource change**

```bash
git add argocd/base/matrix/app.yaml
git commit -m "fix(matrix): increase PostgreSQL CPU limit"
```

---

### Task 2: Disable invalid standalone K3s component monitoring

**Files:**
- Modify: `argocd/base/kube-prometheus-stack/app.yaml:68-79`

**Interfaces:**
- Consumes: kube-prometheus-stack `79.12.0` component gates.
- Produces: Helm values that omit the controller-manager, scheduler, and kube-proxy ServiceMonitors and their dependent rules.

- [ ] **Step 1: Add the three component gates**

Add these alphabetically sorted top-level siblings within `valuesObject`, immediately after `grafana` and before `prometheusOperator`:

```yaml
        kubeControllerManager:
          enabled: false
        kubeProxy:
          enabled: false
        kubeScheduler:
          enabled: false
```

- [ ] **Step 2: Parse the Application and assert all component gates**

Run:

```bash
yq -e '
  .spec.source.helm.valuesObject.kubeControllerManager.enabled == false and
  .spec.source.helm.valuesObject.kubeProxy.enabled == false and
  .spec.source.helm.valuesObject.kubeScheduler.enabled == false
' argocd/base/kube-prometheus-stack/app.yaml
```

Expected: `true` and exit status 0.

- [ ] **Step 3: Render the pinned monitoring chart**

Run:

```bash
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
yq '.spec.source.helm.valuesObject' argocd/base/kube-prometheus-stack/app.yaml > "$tmpdir/values.yaml"
helm template kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version 79.12.0 \
  --namespace monitoring \
  -f "$tmpdir/values.yaml" \
  > "$tmpdir/rendered.yaml"
```

Expected: Helm exits 0 and writes rendered manifests.

- [ ] **Step 4: Verify the false-positive rules are absent**

Run:

```bash
if rg -n 'KubeControllerManagerDown|KubeProxyDown|KubeSchedulerDown' "$tmpdir/rendered.yaml"; then
  echo "unexpected K3s-incompatible alert rule rendered" >&2
  exit 1
fi
```

Expected: exit status 0 with no matches.

- [ ] **Step 5: Verify the unusable ServiceMonitors are absent**

Run:

```bash
yq -r 'select(.kind == "ServiceMonitor") | .metadata.name' "$tmpdir/rendered.yaml" \
  > "$tmpdir/service-monitors.txt"
if grep -Ex 'kube-prometheus-stack-kube-(controller-manager|proxy|scheduler)' "$tmpdir/service-monitors.txt"; then
  echo "unexpected K3s-incompatible ServiceMonitor rendered" >&2
  exit 1
fi
```

Expected: exit status 0 with no matching ServiceMonitor names.

- [ ] **Step 6: Validate repository composition and scope**

Run:

```bash
kubectl kustomize argocd/homelab/apps > "$tmpdir/apps.yaml"
test -s "$tmpdir/apps.yaml"
git diff --check
git diff --name-only
```

Expected:

```text
argocd/base/kube-prometheus-stack/app.yaml
```

The Kustomize output is non-empty and no Grafana log-error file changed.

- [ ] **Step 7: Commit the monitoring cleanup**

```bash
git add argocd/base/kube-prometheus-stack/app.yaml
git commit -m "fix(monitoring): disable invalid K3s component alerts"
```

---

### Task 3: Final branch verification

**Files:**
- Verify: `argocd/base/matrix/app.yaml`
- Verify: `argocd/base/kube-prometheus-stack/app.yaml`
- Verify unchanged: `argocd/homelab/grafana-dashboards/alert-log-errors.yaml`

**Interfaces:**
- Consumes: The committed outputs of Tasks 1 and 2.
- Produces: Review evidence that the complete branch satisfies the design without unrelated changes.

- [ ] **Step 1: Re-run both Helm rendering checks from Tasks 1 and 2**

Run the complete commands from Task 1 Step 3 and Task 2 Steps 3-5 again from a fresh temporary directory.

Expected: both Helm renders exit 0; PostgreSQL has the exact resources; all three alert names and ServiceMonitors are absent.

- [ ] **Step 2: Verify branch scope and commit state**

Run:

```bash
git diff --check main...HEAD
git diff --name-only main...HEAD
git status --short --branch
```

Expected changed files:

```text
argocd/base/kube-prometheus-stack/app.yaml
argocd/base/matrix/app.yaml
docs/plans/2026-07-20-matrix-cpu-k3s-alert-cleanup.md
docs/specs/2026-07-20-matrix-cpu-k3s-alert-cleanup-design.md
```

Expected status: branch `fix/matrix-cpu-k3s-alerts` with no uncommitted files after the plan itself is committed.
