# Local Home Assistant Assist Voice Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a fully local English Home Assistant Assist pipeline for one Android phone, using cluster-internal Wyoming Whisper and Piper services.

**Architecture:** A dedicated `voice-assistant` ArgoCD Application deploys a namespace, two independent `Recreate` Deployments, Longhorn RWO model caches, and ClusterIP Services. Android performs wake-word detection locally with microWakeWord; Home Assistant remains the coordinator and reaches the Wyoming endpoints through Kubernetes DNS.

**Tech Stack:** ArgoCD Application CRs, Kustomize, Kubernetes Deployments/Services/PVCs, Longhorn, `rhasspy/wyoming-whisper`, `rhasspy/wyoming-piper`, Home Assistant Wyoming integration, Android Home Assistant Companion app.

## Global Constraints

- Keep the existing `home-assistant` Deployment unchanged; its Assist settings remain UI-managed in its existing persistent volume.
- Use `voice-assistant` as the dedicated namespace and a separate ArgoCD Application at sync wave `'4'`.
- Use CPU-only processing with one replica each and no `nodeSelector`, GPU, host networking, privileged container, host path, Ingress, NodePort, MQTT, cluster-side openWakeWord, credential, or Secret.
- Use only the cluster-internal endpoints `wyoming-whisper.voice-assistant.svc.cluster.local:10300` and `wyoming-piper.voice-assistant.svc.cluster.local:10200`.
- Use Longhorn `ReadWriteOnce` PVCs mounted at `/data`, `Recreate` Deployment strategy, TCP startup/readiness/liveness probes, and restrictive compatible security contexts.
- Pin the amd64 images to `rhasspy/wyoming-whisper@sha256:308b7959a925d0cca381c3e6e77292fed87822695635db39c24199d6b7a9e610` and `rhasspy/wyoming-piper@sha256:69b7f797ae3a8c3c0202cbf97152fb795d78c2355de2a31655c20671247360d8`.
- Configure Whisper as `base-int8` with language `en`, and Piper with voice `en_US-lessac-medium`.
- Do not add automated tests: the Testing Value Gate excludes static Kubernetes YAML and runbook text. Use Kustomize rendering, `yamllint`, `git diff --check`, and read-only cluster checks instead.
- Deliver the cluster change through Git and let ArgoCD reconcile it. Do not use `kubectl apply`, `kubectl patch`, `kubectl delete`, Helm upgrade, or manual ArgoCD sync.

---

## File Structure

- `argocd/base/voice-assistant/app.yaml` — registers the standalone ArgoCD child Application.
- `argocd/base/voice-assistant/kustomization.yaml` — packages the child Application for the root app.
- `argocd/homelab/apps/kustomization.yaml` — registers the new base package in the root app bundle.
- `argocd/homelab/voice-assistant/namespace.yaml` — declares the dedicated workload namespace.
- `argocd/homelab/voice-assistant/kustomization.yaml` — combines the namespace and both Wyoming services.
- `argocd/homelab/voice-assistant/whisper-pvc.yaml` — persists the Faster Whisper model download cache.
- `argocd/homelab/voice-assistant/whisper-service.yaml` — exposes Faster Whisper only inside the cluster.
- `argocd/homelab/voice-assistant/whisper-deployment.yaml` — runs English `base-int8` Faster Whisper with CPU limits and probes.
- `argocd/homelab/voice-assistant/piper-pvc.yaml` — persists the Piper voice download cache.
- `argocd/homelab/voice-assistant/piper-service.yaml` — exposes Piper only inside the cluster.
- `argocd/homelab/voice-assistant/piper-deployment.yaml` — runs the selected English Piper voice with CPU limits and probes.
- `docs/runbooks/home-assistant-voice-assist.md` — documents post-reconciliation Home Assistant and Android setup, verification, and safe troubleshooting.

### Task 1: Register the ArgoCD application and workload package

**Files:**
- Create: `argocd/base/voice-assistant/app.yaml`
- Create: `argocd/base/voice-assistant/kustomization.yaml`
- Create: `argocd/homelab/voice-assistant/namespace.yaml`
- Create: `argocd/homelab/voice-assistant/kustomization.yaml`
- Modify: `argocd/homelab/apps/kustomization.yaml`

**Interfaces:**
- Consumes: The root app's existing `argocd/homelab/apps/kustomization.yaml` package convention and the standalone Application shape used by `argocd/base/mosquitto/app.yaml`.
- Produces: An automated `voice-assistant` child Application targeting `argocd/homelab/voice-assistant`, plus a renderable child Kustomize package into which Tasks 2 and 3 add workloads.

- [ ] **Step 1: Create the child ArgoCD Application manifest**

Create `argocd/base/voice-assistant/app.yaml` with the same retry and automated-sync policy as Mosquitto. Use wave `4` because the app requires Longhorn, whose child Application is wave `3`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: voice-assistant
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '4'
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/voice-assistant
  destination:
    server: https://kubernetes.default.svc
    namespace: voice-assistant
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 2: Package the child Application**

Create `argocd/base/voice-assistant/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: argocd
resources:
  - app.yaml
kind: Kustomization
```

- [ ] **Step 3: Create the initially renderable workload package**

Create `argocd/homelab/voice-assistant/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: voice-assistant
```

Create `argocd/homelab/voice-assistant/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: voice-assistant
resources:
  - namespace.yaml
kind: Kustomization
```

- [ ] **Step 4: Register the package in the root application bundle**

Update `argocd/homelab/apps/kustomization.yaml` to add `../../base/voice-assistant` after `../../base/victoria-logs` and before `../../base/ziti-controller`. The complete target file is:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: argocd
resources:
  - ../../base/argocd
  - ../../base/cert-manager
  - ../../base/cloudnative-pg
  - ../../base/authentik-db
  - ../../base/authentik
  - ../../base/csi-snapshot-crds
  - ../../base/csi-snapshot-controller
  - ../../base/coturn
  - ../../base/nextcloud-db
  - ../../base/nextcloud
  - ../../base/webmutt
  - ../../base/openclaw-mail-sync
  - ../../base/openclaw
  - ../../base/matrix
  - ../../base/matrix-whatsapp
  - ../../base/miniziti-operator
  - ../../base/garage
  - ../../base/forgejo
  - ../../base/forgejo-runner
  - ../../base/ftp
  - ../../base/infra
  - ../../base/jellyfin
  - ../../base/grafana-postgres
  - ../../base/kube-prometheus-stack
  - ../../base/grafana-dashboards
  - ../../base/local-path-provisioner
  - ../../base/mosquitto
  - ../../base/kyverno
  - ../../base/longhorn
  - ../../base/longhorn-admission-hooks
  - ../../base/openebs-mayastor
  - ../../base/reflector
  - ../../base/sealed-secrets
  - ../../base/speedtest-exporter
  - ../../base/traefik
  - ../../base/traefik-private
  - ../../base/trust-manager
  - ../../base/victoria-logs
  - ../../base/voice-assistant
  - ../../base/ziti-controller
  - ../../base/ziti-router
kind: Kustomization
```

- [ ] **Step 5: Render and lint the registration package**

Run:

```sh
kubectl kustomize argocd/base/voice-assistant > /tmp/voice-assistant-application.yaml
kubectl kustomize argocd/homelab/voice-assistant > /tmp/voice-assistant-workload.yaml
kubectl kustomize argocd/homelab/apps > /tmp/root-apps.yaml
yamllint \
  argocd/base/voice-assistant/app.yaml \
  argocd/base/voice-assistant/kustomization.yaml \
  argocd/homelab/apps/kustomization.yaml \
  argocd/homelab/voice-assistant/namespace.yaml \
  argocd/homelab/voice-assistant/kustomization.yaml
git diff --check
```

Expected: all three `kubectl kustomize` commands exit `0`; `yamllint` may emit the repository's existing missing-`---` warnings but exits `0`; `git diff --check` has no output.

- [ ] **Step 6: Commit the ArgoCD registration**

```sh
git add \
  argocd/base/voice-assistant/app.yaml \
  argocd/base/voice-assistant/kustomization.yaml \
  argocd/homelab/apps/kustomization.yaml \
  argocd/homelab/voice-assistant/namespace.yaml \
  argocd/homelab/voice-assistant/kustomization.yaml
git commit -m "feat(voice): register voice assistant app"
```

### Task 2: Deploy the CPU-only Wyoming Faster Whisper endpoint

**Files:**
- Create: `argocd/homelab/voice-assistant/whisper-pvc.yaml`
- Create: `argocd/homelab/voice-assistant/whisper-service.yaml`
- Create: `argocd/homelab/voice-assistant/whisper-deployment.yaml`
- Modify: `argocd/homelab/voice-assistant/kustomization.yaml`

**Interfaces:**
- Consumes: The `voice-assistant` namespace and Kustomize package from Task 1; the upstream container entrypoint's `/data` model/download directories.
- Produces: `wyoming-whisper.voice-assistant.svc.cluster.local:10300`, which accepts English audio from Home Assistant through Wyoming Protocol.

- [ ] **Step 1: Declare persistent model storage**

Create `argocd/homelab/voice-assistant/whisper-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wyoming-whisper-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: longhorn
```

- [ ] **Step 2: Expose Whisper to in-cluster consumers**

Create `argocd/homelab/voice-assistant/whisper-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wyoming-whisper
spec:
  type: ClusterIP
  selector:
    app: wyoming-whisper
  ports:
    - name: wyoming
      port: 10300
      targetPort: wyoming
      protocol: TCP
```

- [ ] **Step 3: Create the pinned Faster Whisper Deployment**

Create `argocd/homelab/voice-assistant/whisper-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wyoming-whisper
  labels:
    app: wyoming-whisper
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: wyoming-whisper
  template:
    metadata:
      labels:
        app: wyoming-whisper
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: whisper
          image: rhasspy/wyoming-whisper@sha256:308b7959a925d0cca381c3e6e77292fed87822695635db39c24199d6b7a9e610  # yamllint disable-line rule:line-length
          imagePullPolicy: IfNotPresent
          args:
            - --model
            - base-int8
            - --language
            - en
          ports:
            - name: wyoming
              containerPort: 10300
              protocol: TCP
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          startupProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 5
            timeoutSeconds: 1
            failureThreshold: 60
          readinessProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 10
            timeoutSeconds: 1
            failureThreshold: 3
          livenessProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 10
            timeoutSeconds: 1
            failureThreshold: 3
          resources:
            requests:
              cpu: "1"
              memory: 1Gi
            limits:
              cpu: "4"
              memory: 4Gi
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: wyoming-whisper-data
```

- [ ] **Step 4: Include the Whisper resources in the child package**

Replace `argocd/homelab/voice-assistant/kustomization.yaml` with:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: voice-assistant
resources:
  - namespace.yaml
  - whisper-pvc.yaml
  - whisper-service.yaml
  - whisper-deployment.yaml
kind: Kustomization
```

- [ ] **Step 5: Render and inspect the Whisper endpoint**

Run:

```sh
rendered="$(mktemp)"
kubectl kustomize argocd/homelab/voice-assistant > "$rendered"
rg -F 'name: wyoming-whisper' "$rendered"
rg -F 'rhasspy/wyoming-whisper@sha256:308b7959a925d0cca381c3e6e77292fed87822695635db39c24199d6b7a9e610' "$rendered"
rg -F 'storageClassName: longhorn' "$rendered"
rm -f "$rendered"
yamllint \
  argocd/homelab/voice-assistant/kustomization.yaml \
  argocd/homelab/voice-assistant/whisper-pvc.yaml \
  argocd/homelab/voice-assistant/whisper-service.yaml \
  argocd/homelab/voice-assistant/whisper-deployment.yaml
git diff --check
```

Expected: the rendered output contains the Whisper Deployment, ClusterIP Service, pinned digest, and Longhorn PVC; all commands exit `0` aside from allowed `yamllint` document-start warnings.

- [ ] **Step 6: Commit the Whisper workload**

```sh
git add \
  argocd/homelab/voice-assistant/kustomization.yaml \
  argocd/homelab/voice-assistant/whisper-pvc.yaml \
  argocd/homelab/voice-assistant/whisper-service.yaml \
  argocd/homelab/voice-assistant/whisper-deployment.yaml
git commit -m "feat(voice): add local Whisper service"
```

### Task 3: Deploy the CPU-only Wyoming Piper endpoint

**Files:**
- Create: `argocd/homelab/voice-assistant/piper-pvc.yaml`
- Create: `argocd/homelab/voice-assistant/piper-service.yaml`
- Create: `argocd/homelab/voice-assistant/piper-deployment.yaml`
- Modify: `argocd/homelab/voice-assistant/kustomization.yaml`

**Interfaces:**
- Consumes: The `voice-assistant` namespace and Kustomize package from Task 1; the upstream Piper entrypoint's `/data` model/download directories.
- Produces: `wyoming-piper.voice-assistant.svc.cluster.local:10200`, which synthesizes `en_US-lessac-medium` responses sent by Home Assistant over Wyoming Protocol.

- [ ] **Step 1: Declare persistent Piper voice storage**

Create `argocd/homelab/voice-assistant/piper-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wyoming-piper-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
```

- [ ] **Step 2: Expose Piper to in-cluster consumers**

Create `argocd/homelab/voice-assistant/piper-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wyoming-piper
spec:
  type: ClusterIP
  selector:
    app: wyoming-piper
  ports:
    - name: wyoming
      port: 10200
      targetPort: wyoming
      protocol: TCP
```

- [ ] **Step 3: Create the pinned Piper Deployment**

Create `argocd/homelab/voice-assistant/piper-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wyoming-piper
  labels:
    app: wyoming-piper
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: wyoming-piper
  template:
    metadata:
      labels:
        app: wyoming-piper
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: piper
          image: rhasspy/wyoming-piper@sha256:69b7f797ae3a8c3c0202cbf97152fb795d78c2355de2a31655c20671247360d8  # yamllint disable-line rule:line-length
          imagePullPolicy: IfNotPresent
          args:
            - --voice
            - en_US-lessac-medium
          ports:
            - name: wyoming
              containerPort: 10200
              protocol: TCP
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          startupProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 5
            timeoutSeconds: 1
            failureThreshold: 60
          readinessProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 10
            timeoutSeconds: 1
            failureThreshold: 3
          livenessProbe:
            tcpSocket:
              port: wyoming
            periodSeconds: 10
            timeoutSeconds: 1
            failureThreshold: 3
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: "2"
              memory: 1Gi
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: wyoming-piper-data
```

- [ ] **Step 4: Include the Piper resources in the child package**

Replace `argocd/homelab/voice-assistant/kustomization.yaml` with:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: voice-assistant
resources:
  - namespace.yaml
  - whisper-pvc.yaml
  - whisper-service.yaml
  - whisper-deployment.yaml
  - piper-pvc.yaml
  - piper-service.yaml
  - piper-deployment.yaml
kind: Kustomization
```

- [ ] **Step 5: Render and inspect the full voice workload**

Run:

```sh
rendered="$(mktemp)"
kubectl kustomize argocd/homelab/voice-assistant > "$rendered"
rg -F 'name: wyoming-whisper' "$rendered"
rg -F 'name: wyoming-piper' "$rendered"
rg -F 'rhasspy/wyoming-piper@sha256:69b7f797ae3a8c3c0202cbf97152fb795d78c2355de2a31655c20671247360d8' "$rendered"
rg -F 'containerPort: 10300' "$rendered"
rg -F 'containerPort: 10200' "$rendered"
rm -f "$rendered"
yamllint \
  argocd/homelab/voice-assistant/kustomization.yaml \
  argocd/homelab/voice-assistant/piper-pvc.yaml \
  argocd/homelab/voice-assistant/piper-service.yaml \
  argocd/homelab/voice-assistant/piper-deployment.yaml
git diff --check
```

Expected: the generated manifest contains two Deployments, two ClusterIP Services, two Longhorn RWO PVCs, both pinned images, and both Wyoming ports; all commands exit `0` aside from allowed `yamllint` document-start warnings.

- [ ] **Step 6: Commit the Piper workload**

```sh
git add \
  argocd/homelab/voice-assistant/kustomization.yaml \
  argocd/homelab/voice-assistant/piper-pvc.yaml \
  argocd/homelab/voice-assistant/piper-service.yaml \
  argocd/homelab/voice-assistant/piper-deployment.yaml
git commit -m "feat(voice): add local Piper service"
```

### Task 4: Document configuration, validate the complete GitOps change, and commit

**Files:**
- Create: `docs/runbooks/home-assistant-voice-assist.md`
- Verify: `argocd/base/voice-assistant/app.yaml`
- Verify: `argocd/base/voice-assistant/kustomization.yaml`
- Verify: `argocd/homelab/apps/kustomization.yaml`
- Verify: `argocd/homelab/voice-assistant/*.yaml`

**Interfaces:**
- Consumes: The two Kubernetes DNS endpoints produced by Tasks 2 and 3 and Home Assistant's UI-managed Wyoming integration.
- Produces: An operator-facing procedure for safe GitOps rollout, Home Assistant Assist pipeline setup, Android wake-word enablement, and read-only validation.

- [ ] **Step 1: Write the operator runbook**

Create `docs/runbooks/home-assistant-voice-assist.md`:

````markdown
# Home Assistant local voice Assist

## Scope

This runbook configures the Android Home Assistant Companion app to use the local Wyoming services deployed by the `voice-assistant` ArgoCD Application. Android detects the wake word on-device with microWakeWord. Whisper and Piper remain cluster-internal and do not have an Ingress, NodePort, MQTT connection, or credentials.

## GitOps rollout

1. Merge the GitOps commits to `main` and let the root ArgoCD Application reconcile the `voice-assistant` child Application. Do not manually sync it and do not use direct-write `kubectl` or Helm commands.
2. Wait for the initial model downloads and verify the reconciled runtime with read-only commands:

   ```sh
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n argocd \
     get application voice-assistant
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n voice-assistant \
     get deployment,pod,service,endpoints
   ```

   Both `wyoming-whisper` and `wyoming-piper` Deployments must report `1/1` ready. Each Service must have an endpoint. First startup can take several minutes while the selected models download to their Longhorn PVCs.
3. If a pod remains unready, inspect its events and logs without changing cluster state:

   ```sh
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n voice-assistant \
     describe pod -l app=wyoming-whisper
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n voice-assistant \
     logs deployment/wyoming-whisper
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n voice-assistant \
     describe pod -l app=wyoming-piper
   kubectl --kubeconfig "${KUBECONFIG:-./.kubeconfig}" -n voice-assistant \
     logs deployment/wyoming-piper
   ```

## Home Assistant configuration

1. In Home Assistant, go to **Settings → Devices & services → Add integration** and add **Wyoming Protocol**.
2. Add Faster Whisper using host `wyoming-whisper.voice-assistant.svc.cluster.local` and port `10300`.
3. Add Piper using host `wyoming-piper.voice-assistant.svc.cluster.local` and port `10200`.
4. Go to **Settings → Voice assistants**, create an assistant named **Local English**, and select English with the new Whisper speech-to-text engine and Piper text-to-speech engine.
5. Select **Local English** as the Assist pipeline used by the Android Companion app.

Home Assistant stores these UI selections in its existing `/config` persistent volume. Do not add credentials or Home Assistant runtime state to this Git repository.

## Android configuration and acceptance test

1. In the Android Home Assistant Companion app, open **Settings → Companion app → Assist for Android**.
2. Select the **Local English** pipeline.
3. Enable **Wake word detection** and select one supported local wake word, such as **Hey Nabu**, **Hey Jarvis**, or **Hey Mycroft**.
4. Lock the phone or send the app to the background. Say the selected wake word, then a simple exposed command such as `turn on <an exposed light>`.
5. Confirm that Home Assistant transcribes the request, executes the intended service, and returns a Piper-spoken response through the phone.

Wake-word detection runs continuously on the Android phone and can noticeably affect battery life. Turn it off in the same Android settings when it is not needed.

## Failure boundaries

- If Whisper is unavailable, Home Assistant remains available but cannot transcribe this local voice pipeline.
- If Piper is unavailable, Home Assistant can process the intent but cannot produce a spoken response through this pipeline.
- If a model-cache PVC is recreated, its service downloads the configured model again; wait for the corresponding Deployment to become ready before retesting.
````

- [ ] **Step 2: Render every affected Kustomize entry point and lint all new YAML**

Run:

```sh
kubectl kustomize argocd/base/voice-assistant > /tmp/voice-assistant-application.yaml
kubectl kustomize argocd/homelab/voice-assistant > /tmp/voice-assistant-workload.yaml
kubectl kustomize argocd/homelab/apps > /tmp/root-apps.yaml
yamllint \
  argocd/base/voice-assistant/app.yaml \
  argocd/base/voice-assistant/kustomization.yaml \
  argocd/homelab/apps/kustomization.yaml \
  argocd/homelab/voice-assistant/kustomization.yaml \
  argocd/homelab/voice-assistant/namespace.yaml \
  argocd/homelab/voice-assistant/whisper-pvc.yaml \
  argocd/homelab/voice-assistant/whisper-service.yaml \
  argocd/homelab/voice-assistant/whisper-deployment.yaml \
  argocd/homelab/voice-assistant/piper-pvc.yaml \
  argocd/homelab/voice-assistant/piper-service.yaml \
  argocd/homelab/voice-assistant/piper-deployment.yaml
git diff --check
git status --short
```

Expected: all rendering and lint commands exit `0`, `git diff --check` has no output, and `git status --short` lists only the intended runbook before this task's commit. `yamllint` document-start warnings match existing repository YAML and are non-fatal.

- [ ] **Step 3: Commit the runbook**

```sh
git add docs/runbooks/home-assistant-voice-assist.md
git commit -m "docs(voice): add Assist setup runbook"
```

### Task 5: Reconcile through GitOps and perform the end-to-end acceptance check

**Files:**
- Verify only: `docs/runbooks/home-assistant-voice-assist.md`

**Interfaces:**
- Consumes: The merged `main` branch, ArgoCD's automated reconciliation, the two ready Kubernetes Services, Home Assistant UI access, and one Android phone.
- Produces: A confirmed local Android wake-word request that is transcribed by Whisper, actioned by Home Assistant, and spoken by Piper.

- [ ] **Step 1: Ensure the committed branch is merged into `main` through the normal review path**

Do not push an unreviewed branch directly to a production deployment path. After review and merge, wait for ArgoCD's automated prune/self-heal policy to reconcile the root application and the `voice-assistant` child Application.

- [ ] **Step 2: Execute the runbook's read-only rollout checks**

Run the commands in **GitOps rollout** from `docs/runbooks/home-assistant-voice-assist.md`. Confirm that both Deployments are `1/1` ready and each ClusterIP Service reports an endpoint before configuring Home Assistant.

- [ ] **Step 3: Configure Home Assistant and Android, then run the acceptance command**

Follow **Home Assistant configuration** and **Android configuration and acceptance test** in the runbook. The acceptance command is complete only when one locked/background Android phone hears its local wake word, Home Assistant executes the requested exposed action, and the phone plays the Piper response.

- [ ] **Step 4: Record the outcome in the delivery or pull-request notes**

Record the selected Android wake word, the date of the successful test, and any observed CPU latency. If the command did not complete, record whether the failure was wake-word detection, Whisper transcription, Home Assistant intent handling, or Piper playback; do not attempt a direct cluster mutation as remediation.
