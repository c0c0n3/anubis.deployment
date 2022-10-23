Can only build one sidecar Kustomization at a time
--------------------------------------------------

This dir contains the Kustomization to show the limitation of the
current sidecar `Component` implementation where you can only build
one sidecar Kustomization at a time. See explanation in
- `k8s/infra/sidecar/kustomization.yaml`

To see the issue yourself, cd to this directory and run

```bash
$ kustomize build
Error: accumulating resources:
  accumulation err='accumulating resources from 'one-too-many':
    '[...]/one-too-many' must resolve to a file':
      recursed merging from path '[...]/one-too-many':
        may not add resource with an already registered id:
          ~G_v1_ConfigMap|~X|envoy-config
```

On the other hand building each Kustomization separately works

```bash
$ kustomize build happy-tee-pea
$ kustomize build one-too-many
```
