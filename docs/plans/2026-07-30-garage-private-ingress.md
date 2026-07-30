# Garage Private S3 Ingress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `http://s3.compaan` and Garage bucket hosts under `*.s3.compaan` reach the Garage S3 API from in-cluster clients.

**Architecture:** Keep the existing CoreDNS `.compaan` rewrite and public Garage ingresses unchanged. Add a separately rendered, values-driven `traefik-private` Ingress that routes the internal S3 hostnames to the existing Garage Service on port `3900`.

**Tech Stack:** Kubernetes `networking.k8s.io/v1` Ingress, Helm templates and values, Traefik, Garage S3 API.

## Global Constraints

- Do not change `argocd/homelab/infra/coredns-configmap.yaml`.
- Do not add a Ziti DNS forwarder, DaemonSet, Service, or split-zone configuration.
- Keep the existing public Garage ingresses for `s3-api.croprun.com` and `s3.croprun.com` unchanged.
- The private route must accept both `s3.compaan` and `*.s3.compaan`.
- The private route must use `ingressClassName: traefik-private` and backend Service port `3900`.
- The private endpoint is HTTP-only; do not add TLS configuration.
- Do not mutate the Kubernetes cluster directly. Deliver all changes through Git for ArgoCD reconciliation.
- This is static Helm/Kubernetes configuration and fails the Testing Value Gate for a new automated test. Use `helm lint` and exact rendered-manifest assertions instead.

## File Map

- Modify `argocd/homelab/garage/values.yaml`: define the enabled private S3 API ingress hosts and class.
- Create `argocd/homelab/garage/templates/ingress-private.yaml`: render only the internal Garage S3 API Ingress.
- Do not modify `argocd/homelab/garage/templates/ingress.yaml`: it remains responsible only for the existing public API and web ingresses.

---

### Task 1: Add and verify the private Garage S3 API Ingress

**Files:**
- Modify: `argocd/homelab/garage/values.yaml` under `ingress.s3.api`
- Create: `argocd/homelab/garage/templates/ingress-private.yaml`
- Verify: rendered Helm output in `/tmp/garage-private-ingress-rendered.yaml`

**Interfaces:**
- Consumes: `.Values.ingress.s3.api.private`, `.Values.service.s3.api.port`, and the existing `garage.fullname` and `garage.labels` Helm helpers.
- Produces: `networking.k8s.io/v1` Ingress `garage-s3-api-private`, with host rules for `s3.compaan` and `*.s3.compaan`, routing `/` to Service `garage` port `3900` through `traefik-private`.

- [ ] **Step 1: Confirm the private route is absent from the baseline render**

Run:

```bash
helm template garage argocd/homelab/garage --namespace garage \
  >/tmp/garage-private-ingress-baseline.yaml

yq -r '
  select(.kind == "Ingress")
  | [.metadata.name, .spec.ingressClassName, (.spec.rules | map(.host) | join(","))]
  | @tsv
' /tmp/garage-private-ingress-baseline.yaml
```

Expected output:

```text
garage-s3-api	traefik-public	s3-api.croprun.com
garage-s3-web	traefik-public	s3.croprun.com
```

There must be no `garage-s3-api-private` row.

- [ ] **Step 2: Add the private ingress values**

In `argocd/homelab/garage/values.yaml`, add this block at the end of `ingress.s3.api`, after the existing public `tls` block and before the sibling `web` block:

```yaml
      private:
        enabled: true
        className: traefik-private
        annotations: {}
        labels: {}
        hosts:
          - host: "s3.compaan"
            paths:
              - path: /
                pathType: Prefix
          - host: "*.s3.compaan"
            paths:
              - path: /
                pathType: Prefix
```

Do not change the existing public API host, class, annotations, or TLS values.

- [ ] **Step 3: Create the focused private ingress template**

Create `argocd/homelab/garage/templates/ingress-private.yaml` with exactly:

```yaml
{{- if .Values.ingress.s3.api.private.enabled -}}
{{- $fullName := include "garage.fullname" . -}}
{{- $svcPort := .Values.service.s3.api.port -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}-s3-api-private
  labels:
    {{- include "garage.labels" . | nindent 4 }}
    {{- with .Values.ingress.s3.api.private.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.ingress.s3.api.private.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.s3.api.private.className }}
  rules:
    {{- range .Values.ingress.s3.api.private.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
```

This template intentionally omits `tls` because the required endpoint is `http://s3.compaan`.

- [ ] **Step 4: Lint the Garage chart**

Run:

```bash
helm lint argocd/homelab/garage
```

Expected output includes:

```text
1 chart(s) linted, 0 chart(s) failed
```

- [ ] **Step 5: Render and assert the private route exactly**

Run:

```bash
helm template garage argocd/homelab/garage --namespace garage \
  >/tmp/garage-private-ingress-rendered.yaml

actual="$(yq -r '
  select(.kind == "Ingress" and .metadata.name == "garage-s3-api-private")
  | [
      .metadata.name,
      .spec.ingressClassName,
      (.spec.rules | map(.host) | join(",")),
      (.spec.rules | map(.http.paths[].backend.service.port.number | tostring) | join(","))
    ]
  | @tsv
' /tmp/garage-private-ingress-rendered.yaml)"
expected="$(printf 'garage-s3-api-private\ttraefik-private\ts3.compaan,*.s3.compaan\t3900,3900')"
printf '%s\n' "$actual"
test "$actual" = "$expected"
```

Expected output:

```text
garage-s3-api-private	traefik-private	s3.compaan,*.s3.compaan	3900,3900
```

The command must exit `0`.

- [ ] **Step 6: Confirm the public routes remain unchanged**

Run:

```bash
yq -r '
  select(
    .kind == "Ingress"
    and (.metadata.name == "garage-s3-api" or .metadata.name == "garage-s3-web")
  )
  | [
      .metadata.name,
      .spec.ingressClassName,
      (.spec.rules | map(.host) | join(",")),
      (.spec.rules | map(.http.paths[].backend.service.port.number | tostring) | join(","))
    ]
  | @tsv
' /tmp/garage-private-ingress-rendered.yaml

git diff --exit-code -- argocd/homelab/garage/templates/ingress.yaml
```

Expected output:

```text
garage-s3-api	traefik-public	s3-api.croprun.com	3900
garage-s3-web	traefik-public	s3.croprun.com	3902
```

Both commands must exit `0`.

- [ ] **Step 7: Review the final change set**

Run:

```bash
git diff --check
git status --short
git diff -- argocd/homelab/garage/values.yaml \
  argocd/homelab/garage/templates/ingress-private.yaml
```

Expected status contains only:

```text
 M argocd/homelab/garage/values.yaml
?? argocd/homelab/garage/templates/ingress-private.yaml
```

Confirm the diff contains no CoreDNS, Ziti, public-ingress, TLS, or unrelated changes.

- [ ] **Step 8: Commit the implementation**

```bash
git add argocd/homelab/garage/values.yaml \
  argocd/homelab/garage/templates/ingress-private.yaml
git commit -m "fix(garage): route private S3 endpoint"
```
