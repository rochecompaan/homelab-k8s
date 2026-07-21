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
