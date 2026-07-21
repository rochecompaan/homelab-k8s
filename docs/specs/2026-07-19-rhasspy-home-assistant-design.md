# Local Home Assistant Assist Voice Pipeline Design

## Goal

Add a fully local, English Home Assistant Assist voice pipeline for one Android phone. The phone detects the wake word locally; Kubernetes provides local speech-to-text and text-to-speech through Wyoming Protocol services.

## Scope

Create a dedicated `voice-assistant` ArgoCD Application and workload package that deploys:

- Wyoming Faster Whisper for English speech-to-text.
- Wyoming Piper for English text-to-speech.
- Persistent model caches and cluster-internal Services for both workloads.

Configure the Home Assistant and Android companion settings manually after the GitOps workloads reconcile.

## Non-goals

- Deploy classic Rhasspy 2.5, MQTT intent handling, or a cluster-side wake-word service.
- Expose voice services through an Ingress, NodePort, or public endpoint.
- Support iOS or more than one concurrent voice interaction.
- Add GPUs, host networking, privileged pods, or credentials/secrets.

## Architecture

Add `argocd/base/voice-assistant/` following the existing standalone ArgoCD Application pattern, and register it in `argocd/homelab/apps/kustomization.yaml`. The Application targets `argocd/homelab/voice-assistant/`, creates the `voice-assistant` namespace, and enables automated prune and self-heal.

The Kustomize package contains the namespace, model-cache PVCs, Deployments, Services, and its own `kustomization.yaml`. It has two independently deployable, single-replica services:

| Service | Implementation | Port | Initial model |
| --- | --- | ---: | --- |
| `wyoming-whisper` | Faster Whisper | 10300 | `base-int8`, English (`en`) |
| `wyoming-piper` | Piper | 10200 | `en_US-lessac-medium` |

Each workload mounts its own Longhorn ReadWriteOnce PVC at `/data` so downloaded models survive a pod restart. Each Deployment uses `Recreate` to avoid an overlapping rollout that could contend for an RWO volume. The workloads are not pinned to a specific node; the scheduler can place them on any suitable amd64 cluster node.

Container images must be locked to immutable versions or digests, rather than a floating tag. The implementation plan will select a current compatible immutable reference and retain the upstream Wyoming command-line arguments required to listen on all interfaces and persist model downloads in `/data`.

## Request flow

1. The Android Home Assistant Companion app detects its selected wake word locally with microWakeWord, including when the phone is locked or the app is in the background.
2. After activation, the phone sends the command audio to Home Assistant through the existing `ha.compaan` endpoint.
3. Home Assistant sends the audio to `wyoming-whisper.voice-assistant.svc.cluster.local:10300` over the cluster network.
4. Whisper returns the English transcription. Home Assistant resolves the intent and runs any eligible automation or service.
5. Home Assistant sends its textual response to `wyoming-piper.voice-assistant.svc.cluster.local:10200`.
6. Piper returns synthesized audio for Home Assistant to play on the Android phone.

Home Assistant is the sole coordinator for the request. The Wyoming services do not need access to Home Assistant credentials, MQTT, an Ingress, or the Android device.

## Home Assistant configuration boundary

After ArgoCD makes the services available, configure both manually in Home Assistant under **Settings → Devices & services → Add integration → Wyoming Protocol**, using the two cluster DNS names and ports above. Create an English Assist pipeline with Whisper selected for speech-to-text and Piper selected for text-to-speech. Select that Assist pipeline in the Android companion app and enable its local wake-word detection.

These UI settings are runtime configuration stored in Home Assistant's existing persistent configuration volume. They are intentionally not represented as Git-managed Home Assistant files because this repository currently does not manage Home Assistant Assist configuration declaratively.

## Resources, resilience, and security

Start with the following CPU-only resource envelope for a single concurrent Android user:

| Workload | CPU request / limit | Memory request / limit |
| --- | --- | --- |
| Whisper | `1` / `4` | `1Gi` / `4Gi` |
| Piper | `100m` / `2` | `256Mi` / `1Gi` |

Add TCP startup, readiness, and liveness probes to the Wyoming ports. The startup budget must allow first-run model downloads. Readiness only proves that the service is accepting connections; the end-to-end Android test confirms a model can actually transcribe and synthesize speech.

Keep all Services as `ClusterIP`. Apply a restrictive container security context compatible with the upstream images: no privilege escalation, all Linux capabilities dropped, and `RuntimeDefault` seccomp. Do not use host networking, host paths, or privileged containers. Model-cache loss is recoverable because the services download their selected model again; the initial start therefore requires outbound access to their model sources.

A failed Whisper or Piper pod must not disrupt Home Assistant. It makes only the corresponding stage of the Assist pipeline unavailable until Kubernetes restarts the pod or ArgoCD reconciles it.

## Verification

The Testing Value Gate excludes new automated tests because this change is static Kubernetes and ArgoCD configuration; a unit test would only restate YAML contents. Verify directly instead:

1. Render the root app bundle and the new voice-assistant package with Kustomize.
2. Run the repository's available YAML/Kubernetes schema and formatting checks without modifying the cluster.
3. Confirm the ArgoCD Application reconciles using read-only status checks; confirm both pods are ready and both ClusterIP Services have endpoints.
4. In Home Assistant, add the two Wyoming integrations and create the English Assist pipeline.
5. On the Android device, enable a local wake word, issue a simple home-control command, and confirm transcription, intent execution, and spoken Piper response.

All delivery remains GitOps-only: no direct-write `kubectl` or Helm commands are used against the homelab cluster.
