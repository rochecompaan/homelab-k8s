# Garage S3 API Croprun Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose Garage's S3 API at `https://s3-api.croprun.com/<bucket>/<key>` using path-style requests on the new public endpoint.

**Architecture:** Enable the existing Garage chart's S3 API Ingress with a single Traefik host and cert-manager TLS entry. Leave `garage.s3.api.rootDomain` unchanged and do not add any wildcard API ingress host for `s3-api.croprun.com`.

**Tech Stack:** Helm chart values, Kubernetes Ingress, Traefik, cert-manager, Garage S3 API, ArgoCD GitOps.

## Global Constraints

- Work in `/home/roche/homelab-k8s/.worktrees/garage-s3-api-croprun` on branch `garage-s3-api-croprun`.
- Do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade`; all homelab changes must go through Git for ArgoCD to reconcile.
- Preserve the existing Garage website ingress at `s3.croprun.com`.
- Preserve the existing `garage.s3.api.rootDomain` value.
- Do not add wildcard DNS, wildcard TLS, or an API host like `*.s3-api.croprun.com`.
- Do not expose the Garage admin API.
- Use Helm rendering as verification; this configuration change does not justify a new committed automated test file under the Testing Value Gate.
- Commit with Conventional Commits and do not bypass signing or hooks.

---

## File Structure

- Modify `argocd/homelab/garage/values.yaml`
  - Enable `ingress.s3.api`.
  - Configure one API host: `s3-api.croprun.com`.
  - Configure Traefik ingress class, cert-manager issuer annotation, and a dedicated TLS secret.
- Do not modify `argocd/homelab/garage/templates/configmap.yaml`; the existing Garage S3 API `rootDomain` must remain rendered as it is today.
- No new source files are required.

---

### Task 1: Enable Garage S3 API ingress for s3-api.croprun.com

**Files:**
- Modify: `argocd/homelab/garage/values.yaml:159-184`

**Interfaces:**
- Consumes: Existing Garage Helm values structure under `ingress.s3.api`.
- Produces: A rendered Ingress named `garage-s3-api` that routes `s3-api.croprun.com` to Garage service port `3900` without adding `*.s3-api.croprun.com`.

- [ ] **Step 1: Run the render assertion before changes and confirm it fails for the missing API exposure**

Run this command from `/home/roche/homelab-k8s/.worktrees/garage-s3-api-croprun`:

```bash
python3 <<'PY'
import subprocess
import sys

rendered = subprocess.check_output([
    "helm",
    "template",
    "garage",
    "argocd/homelab/garage",
    "--namespace",
    "garage",
], text=True)
s3_api_section = rendered.split("[s3_api]", 1)[1].split("[s3_web]", 1)[0]

checks = [
    ("api ingress rendered", "name: garage-s3-api" in rendered),
    ("api host configured", "host: \"s3-api.croprun.com\"" in rendered or "host: s3-api.croprun.com" in rendered),
    ("api service port 3900", "number: 3900" in rendered),
    ("no wildcard api host", "*.s3-api.croprun.com" not in rendered),
    ("s3 api root_domain unchanged", "root_domain = \".s3.compaan\"" in s3_api_section),
    ("web ingress unchanged", "name: garage-s3-web" in rendered and "s3.croprun.com" in rendered and "number: 3902" in rendered),
]

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
if failed:
    print("FAILED_CHECKS=" + ", ".join(failed))
    sys.exit(1)
PY
```

Expected output before implementation:

```text
FAIL: api ingress rendered
FAIL: api host configured
FAIL: api service port 3900
PASS: no wildcard api host
PASS: s3 api root_domain unchanged
PASS: web ingress unchanged
FAILED_CHECKS=api ingress rendered, api host configured, api service port 3900
```

- [ ] **Step 2: Enable the S3 API ingress for the single path-style host**

In `argocd/homelab/garage/values.yaml`, replace this block:

```yaml
    api:
      enabled: false
      # -- Rely _either_ on the className or the annotation below but not both!
      # If you want to use the className, set
      # className: "nginx"
      # and replace "nginx" by an Ingress controller name,
      # examples [here](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers).
      annotations: {}
        # kubernetes.io/ingress.class: "nginx"
        # kubernetes.io/tls-acme: "true"
      labels: {}
      hosts:
        # -- garage S3 API endpoint, to be used with awscli for example
        - host: "s3.garage.tld"
          paths:
            - path: /
              pathType: Prefix
        # -- garage S3 API endpoint, DNS style bucket access
        - host: "*.s3.garage.tld"
          paths:
            - path: /
              pathType: Prefix
      tls: []
      #  - secretName: my-garage-cluster-tls
      #    hosts:
      #      - kubernetes.docker.internal
```

with this block:

```yaml
    api:
      enabled: true
      # -- Rely _either_ on the className or the annotation below but not both!
      # If you want to use the className, set
      # className: "nginx"
      # and replace "nginx" by an Ingress controller name,
      # examples [here](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers).
      className: traefik
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
      labels: {}
      hosts:
        # -- Garage S3 API endpoint, path-style access on s3-api.croprun.com.
        - host: "s3-api.croprun.com"
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: garage-s3-api-croprun-com-tls
          hosts:
            - s3-api.croprun.com
```

- [ ] **Step 3: Run the render assertion again and confirm it passes**

Run this command from `/home/roche/homelab-k8s/.worktrees/garage-s3-api-croprun`:

```bash
python3 <<'PY'
import subprocess
import sys

rendered = subprocess.check_output([
    "helm",
    "template",
    "garage",
    "argocd/homelab/garage",
    "--namespace",
    "garage",
], text=True)
s3_api_section = rendered.split("[s3_api]", 1)[1].split("[s3_web]", 1)[0]

checks = [
    ("api ingress rendered", "name: garage-s3-api" in rendered),
    ("api host configured", "host: \"s3-api.croprun.com\"" in rendered or "host: s3-api.croprun.com" in rendered),
    ("api service port 3900", "number: 3900" in rendered),
    ("no wildcard api host", "*.s3-api.croprun.com" not in rendered),
    ("s3 api root_domain unchanged", "root_domain = \".s3.compaan\"" in s3_api_section),
    ("web ingress unchanged", "name: garage-s3-web" in rendered and "s3.croprun.com" in rendered and "number: 3902" in rendered),
]

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
if failed:
    print("FAILED_CHECKS=" + ", ".join(failed))
    sys.exit(1)
PY
```

Expected output after implementation:

```text
PASS: api ingress rendered
PASS: api host configured
PASS: api service port 3900
PASS: no wildcard api host
PASS: s3 api root_domain unchanged
PASS: web ingress unchanged
```

- [ ] **Step 4: Inspect the rendered API ingress and ConfigMap snippets**

Run:

```bash
helm template garage argocd/homelab/garage --namespace garage \
  | awk '
      /name: garage-s3-api/{show=1}
      /name: garage-s3-web/{show=0}
      show{print}
    '
```

Expected API ingress details in the output:

```yaml
name: garage-s3-api
cert-manager.io/cluster-issuer: letsencrypt-prod
ingressClassName: traefik
- "s3-api.croprun.com"
secretName: garage-s3-api-croprun-com-tls
- host: "s3-api.croprun.com"
number: 3900
```

Run:

```bash
helm template garage argocd/homelab/garage --namespace garage \
  | awk '
      /\[s3_api\]/{show=1}
      /\[s3_web\]/{print; show=0}
      show{print}
    '
```

Expected S3 API config details in the output:

```toml
[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.compaan"
[s3_web]
```

- [ ] **Step 5: Review the diff**

Run:

```bash
git diff -- argocd/homelab/garage/values.yaml
```

Expected changes:

```text
- `ingress.s3.api.enabled` changes from `false` to `true`.
- `ingress.s3.api.className: traefik` is added.
- `ingress.s3.api.annotations.cert-manager.io/cluster-issuer: letsencrypt-prod` is added.
- API ingress hosts contain only `s3-api.croprun.com`.
- API ingress TLS uses `garage-s3-api-croprun-com-tls` for `s3-api.croprun.com`.
- `garage.s3.api.rootDomain` is not changed.
- `argocd/homelab/garage/templates/configmap.yaml` is not changed.
```

- [ ] **Step 6: Commit the implementation**

Run:

```bash
git status --short
git add argocd/homelab/garage/values.yaml
git commit -m "feat(garage): expose s3 api ingress"
```

Expected commit result:

```text
[garage-s3-api-croprun <sha>] feat(garage): expose s3 api ingress
```
