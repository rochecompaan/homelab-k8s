# Remove Matrix WhatsApp Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove active `matrix-whatsapp` runtime, Synapse appservice, secret, and operations configuration while preserving historical documentation.

**Architecture:** Use a safe two-phase GitOps decommission. Phase 1 keeps the child ArgoCD Application registered, adds the ArgoCD resources finalizer, and points it at an empty desired set so automated prune removes live bridge resources. Phase 2, after ArgoCD confirms no managed resources remain, can delete the temporary empty Application and directories.

**Tech Stack:** Kubernetes manifests, Kustomize, ArgoCD Applications, Helm values, Justfile, Bash, Grafana alert provisioning YAML.

## Global Constraints

- Do not mutate homelab Kubernetes resources directly from the workstation.
- Deliver all cluster changes through repository edits so ArgoCD reconciles them.
- Keep historical docs, specs, plans, and benchmark logs unchanged.
- Keep `matrix-whatsapp` ArgoCD Application temporarily for safe pruning; remove it in a follow-up after ArgoCD confirms no managed resources remain.
- Use static verification commands only.

---

### Task 1: Remove active workload manifests and Synapse wiring

**Files:**
- Modify: `argocd/base/matrix-whatsapp/app.yaml`
- Modify: `argocd/base/matrix/app.yaml`
- Modify: `argocd/homelab/matrix-whatsapp/kustomization.yaml`
- Modify: `argocd/homelab/matrix-whatsapp/README.md`
- Delete: `argocd/homelab/matrix-whatsapp/configmap.yaml`
- Delete: `argocd/homelab/matrix-whatsapp/deployment.yaml`
- Delete: `argocd/homelab/matrix-whatsapp/postgres-cluster.yaml`
- Delete: `argocd/homelab/matrix-whatsapp/service.yaml`

**Interfaces:**
- Consumes: existing ArgoCD child app and Matrix Helm values.
- Produces: child app remains present for pruning but desired state is empty; Synapse no longer loads the WhatsApp appservice registration.

- [ ] **Step 1: Keep `../../base/matrix-whatsapp` in `argocd/homelab/apps/kustomization.yaml` for phase 1 pruning.**

- [ ] **Step 2: Add `resources-finalizer.argocd.argoproj.io` to `argocd/base/matrix-whatsapp/app.yaml`.**

- [ ] **Step 3: Replace `argocd/homelab/matrix-whatsapp/kustomization.yaml` with an empty desired state.**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
```

- [ ] **Step 4: Remove `homeserverConfig.app_service_config_files`, `extraVolumes`, and `extraVolumeMounts` entries dedicated to `whatsapp-appservice` from `argocd/base/matrix/app.yaml`.**

- [ ] **Step 5: Delete the old bridge workload files and replace the README with decommission notes.**

- [ ] **Step 6: Verify GitOps rendering.**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/homelab-apps.yaml
kubectl kustomize argocd/base/matrix >/tmp/matrix-app.yaml
kubectl kustomize argocd/homelab/matrix-whatsapp >/tmp/matrix-whatsapp-empty.yaml
```

Expected: all commands exit 0; Matrix output does not contain `whatsapp-registration`; the matrix-whatsapp overlay renders an empty resource set.

### Task 2: Remove active secrets, helpers, and monitoring references

**Files:**
- Modify: `argocd/homelab/infra/kustomization.yaml`
- Delete: `argocd/homelab/infra/matrix-whatsapp-secret.yaml`
- Delete: `argocd/homelab/infra/matrix-whatsapp-registration.yaml.tpl`
- Modify: `Justfile`
- Modify: `scripts/emergency-scale-down-stateful.sh`
- Modify: `scripts/emergency-scale-up-stateful.sh`
- Modify: `argocd/homelab/grafana-dashboards/alert-backups.yaml`

**Interfaces:**
- Consumes: existing infra Kustomize bundle, Just recipes, emergency scripts, and Grafana provisioned alert rule.
- Produces: active operations no longer reference the retired appservice secret, bridge helper, or bridge database.

- [ ] **Step 1: Remove `matrix-whatsapp-secret.yaml` from `argocd/homelab/infra/kustomization.yaml`.**

- [ ] **Step 2: Delete the sealed secret and registration template files.**

- [ ] **Step 3: Remove `matrix_whatsapp_*` variables and `seal-matrix-whatsapp-secret` recipe from `Justfile`.**

- [ ] **Step 4: Remove `matrix-whatsapp` from both emergency script default app lists.**

- [ ] **Step 5: Change the CNPG backup freshness alert PromQL to target only `nextcloud-db/postgres`.**

- [ ] **Step 6: Verify infra rendering and runtime reference cleanup.**

Run:

```bash
kubectl kustomize argocd/homelab/infra >/tmp/homelab-infra.yaml
bash -n scripts/emergency-scale-down-stateful.sh scripts/emergency-scale-up-stateful.sh
just --list >/tmp/just-list.txt
rg -n 'matrix-whatsapp-appservice|matrix_whatsapp|whatsapp-registration|matrix-whatsapp-postgres|mautrix/whatsapp|mautrix-whatsapp' \
  argocd scripts Justfile \
  --glob '!docs/**'
```

Expected: Kustomize, Bash syntax, and Just listing exit 0; the search returns no active runtime references.
