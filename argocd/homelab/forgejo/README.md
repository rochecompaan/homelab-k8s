# Forgejo

This directory contains bootstrap manifests for the Forgejo ArgoCD app.

## Admin secret

Generate the sealed admin Secret with:

```sh
just seal-forgejo-admin-secret
```

Environment variables:

- `FORGEJO_ADMIN_USERNAME` (default: `roche`)
- `FORGEJO_ADMIN_PASSWORD` (optional, generated if unset)

The recipe writes:

- `argocd/homelab/forgejo/bootstrap/admin-secret.yaml`
- `argocd/homelab/forgejo/bootstrap/kustomization.yaml`

## Email notifications

Forgejo submits account and repository notification mail through
`mail.upfronthosting.co.za:587` with STARTTLS. The external certificate,
renewal, sender-authentication, and recovery procedure is documented in
[`docs/runbooks/forgejo-email.md`](../../../docs/runbooks/forgejo-email.md).

Generate the sealed SMTP password Secret with:

```sh
just seal-forgejo-mailer-secret
```

The recipe reads only the first line from:

- `pass show FORGEJO_SMTP_PASSWORD`

It writes:

- `argocd/homelab/forgejo/bootstrap/mailer-secret.yaml`

When rotating the password, commit the regenerated SealedSecret and increment
`homelab.compaan.cloud/forgejo-mailer-secret-revision` in the Forgejo Helm
values in the same change. ArgoCD performs the rollout; do not restart the
Deployment directly.

## Forgejo Actions runner

Forgejo Actions are enabled in the Forgejo Helm values. Generate the sealed
runner registration Secret with:

```sh
just seal-forgejo-action-runner-secret
```

The recipe reads the registration token from:

- `pass show FORGEJO_ACTION_RUNNER_TOKEN`

The recipe writes:

- `argocd/homelab/forgejo/bootstrap/runner-init-secret.yaml`

This app also bootstraps ArgoCD OCI Helm repository secrets for:

- `code.forgejo.org/forgejo-helm`
- `codeberg.org/wrenix/helm-charts`

## Hostname

Forgejo is exposed at:

- `https://git.compaan.cloud`

## Forgejo Actions runner Nix store

The trusted Forgejo Actions runner persists `/nix` on the
`forgejo-runner-nix-store` PVC. The claim requests 100 GiB from
`longhorn-sata` and is mounted read-write into the DinD and job containers.
Keep the runner at one replica and capacity one. The namespaced
`forgejo-runner-recreate` Kyverno Policy replaces the exact runner Deployment
strategy with `Recreate`, serializing planned Deployment revision rollouts.
`ReadWriteOnce` prevents multi-node attachment but is not pod-exclusive: an
evicted or manually deleted pod can overlap its same-node replacement while
terminating. This residual risk is explicitly accepted for this trusted runner;
avoid disruptive runner operations while jobs are active and do not describe
this design as a universal single-writer guarantee.

The store is disposable and is not backed up. Normal rollout, rollback,
replacement, and claim removal are GitOps-only. For corrupt state, declare a
versioned replacement claim, update the runner claim reference, verify cold and
warm jobs, retain the old claim for inspection, and remove it through GitOps
only after it is no longer referenced. Never delete or repair `/nix` from a job.

### Recovery-only retained-volume cleanup

The function below is an exceptional manual recovery procedure, not a rollout
or verification command. Invoke it only after explicit approval and after Argo
CD has removed the former PVC. Every guard aborts on failure. It distinguishes
an absent claim from API/auth/network failure, proves the Deployment pod
template and every live runner pod omit the claim, first selects every PV with the
exact claim reference and requires exactly one, then proves that sole PV is
`Released` and `longhorn-sata`, proves Longhorn CSI identity,
proves the backing volume is detached, and proves both delete permissions before
either delete.

```bash
cleanup_released_forgejo_runner_nix_claim() {
  local old_claim="${1:-}"
  local kubeconfig=.kubeconfig
  local pvc_result deployment_json pods_json pv_list exact_claim_pvs pv_name pv_json volume_handle volume_json

  if [[ -z "$old_claim" ]]; then
    echo "abort: pass the exact former PVC name" >&2
    return 2
  fi

  if ! pvc_result="$(kubectl --kubeconfig "$kubeconfig" -n forgejo \
      get pvc "$old_claim" --ignore-not-found -o name)"; then
    echo "abort: PVC read failed; absence is not proven" >&2
    return 1
  fi
  if [[ -n "$pvc_result" ]]; then
    echo "abort: PVC forgejo/$old_claim still exists" >&2
    return 1
  fi

  if ! deployment_json="$(kubectl --kubeconfig "$kubeconfig" -n forgejo \
      get deployment forgejo-runner -o json)"; then
    echo "abort: runner Deployment cannot be read" >&2
    return 1
  fi
  if ! jq -e --arg claim "$old_claim" '
      all(.spec.template.spec.volumes[]?;
        .persistentVolumeClaim.claimName != $claim)
    ' >/dev/null <<<"$deployment_json"; then
    echo "abort: runner Deployment pod template still references the claim" >&2
    return 1
  fi

  if ! pods_json="$(kubectl --kubeconfig "$kubeconfig" -n forgejo \
      get pods -l app.kubernetes.io/instance=forgejo-runner -o json)"; then
    echo "abort: rendered runner pods cannot be read" >&2
    return 1
  fi
  if ! jq -e --arg claim "$old_claim" '
      all(.items[];
        all(.spec.volumes[]?; .persistentVolumeClaim.claimName != $claim))
    ' >/dev/null <<<"$pods_json"; then
    echo "abort: a rendered runner pod still references the claim" >&2
    return 1
  fi

  if ! pv_list="$(kubectl --kubeconfig "$kubeconfig" get pv -o json)"; then
    echo "abort: PV list failed" >&2
    return 1
  fi
  if ! exact_claim_pvs="$(jq -ec --arg claim "$old_claim" '
      [ .items[]
        | select(
            .spec.claimRef.namespace == "forgejo" and
            .spec.claimRef.name == $claim
          )
      ]
      | if length == 1 then .
        else error("expected exactly one PV with the exact former claim reference")
        end
    ' <<<"$pv_list")"; then
    echo "abort: exact-claim PV uniqueness guard failed" >&2
    return 1
  fi
  if ! pv_name="$(jq -er '
      .[0]
      | if .status.phase == "Released" and .spec.storageClassName == "longhorn-sata"
        then .metadata.name
        else error("sole exact-claim PV is not Released longhorn-sata")
        end
    ' <<<"$exact_claim_pvs")"; then
    echo "abort: sole exact-claim PV phase/storage-class guard failed" >&2
    return 1
  fi

  if ! pv_json="$(kubectl --kubeconfig "$kubeconfig" get pv "$pv_name" -o json)"; then
    echo "abort: selected PV cannot be read" >&2
    return 1
  fi
  if ! volume_handle="$(jq -er '
      if .spec.csi.driver == "driver.longhorn.io" and
         (.spec.csi.volumeHandle | type == "string" and length > 0)
      then .spec.csi.volumeHandle
      else error("selected PV is not a Longhorn CSI PV")
      end
    ' <<<"$pv_json")"; then
    echo "abort: Longhorn CSI driver/handle guard failed" >&2
    return 1
  fi

  if ! volume_json="$(kubectl --kubeconfig "$kubeconfig" -n longhorn-system \
      get volumes.longhorn.io "$volume_handle" -o json)"; then
    echo "abort: Longhorn backing volume cannot be read" >&2
    return 1
  fi
  if ! jq -e '.status.state == "detached"' >/dev/null <<<"$volume_json"; then
    echo "abort: Longhorn backing volume is not detached" >&2
    return 1
  fi

  if ! kubectl --kubeconfig "$kubeconfig" auth can-i delete \
      "persistentvolumes/$pv_name" --quiet; then
    echo "abort: no permission to delete the selected PV" >&2
    return 1
  fi
  if ! kubectl --kubeconfig "$kubeconfig" auth can-i delete \
      "volumes.longhorn.io/$volume_handle" -n longhorn-system --quiet; then
    echo "abort: no permission to delete the selected Longhorn volume" >&2
    return 1
  fi

  if ! kubectl --kubeconfig "$kubeconfig" delete pv "$pv_name"; then
    echo "abort: selected PV deletion failed; backing volume was not deleted" >&2
    return 1
  fi
  if ! kubectl --kubeconfig "$kubeconfig" -n longhorn-system \
      delete volumes.longhorn.io "$volume_handle"; then
    echo "abort: Longhorn volume deletion failed; do not broaden cleanup" >&2
    return 1
  fi
}
```
