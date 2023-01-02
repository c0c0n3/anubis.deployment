Component patch not applied when using helmChart generator
----------------------------------------------------------

After inflating a Helm chart, applying a patch defined in a separate
`Component` has no effect. Opened a GitHub Kustomize issue about it:

- https://github.com/kubernetes-sigs/kustomize/issues/4841

The setup to reproduce the issue is documented below. The problem with
this setup is that both `helmCharts` and `components` stanzas are in
the same file, but Kustomize processes components before generators
(like `helmCharts`) so the patch the `Component` brings in winds up
in the sink of no return. The Kustomize guys commented on the issue
suggesting the component should be declared in an overlay that also
includes a Helm chart Kustomization from a separate directory---see
fix they explained in the comments. Case closed? I'd say yes, but
it'd be nice if you were able to keep both stanzas in the same file
as documented in the setup below. So I'll keep the below docs for
the record.


### Overview

In a nutshell, this is the setup:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
# the chart to inflate
- name: the-chart
  repo: http://some.where/over/the/rainbow
# ... other fields

components:
# a component containing a patch to apply after inflation
- ../component
```


### Tool versions

To use the `helmChart` generator, you've got to have Helm 3 in your
path besides Kustomize. Here's the exact versions used to test as
reported by the respective `version` commands.

#### Operating system
* Mac OS 11.0.1 (Big Sur)
* (Go) architecture/os: `amd64`/`darwin`

#### Helm
* Version: `v3.7.1`
* Git commit: `1d11fcb5d3f3bf00dbe6fe31b8412839a96b3dc4`
* Go version: `go1.16.13`

#### Kustomize
The issue is there both in an old version
* Version: `4.4.0`
* Git commit: `9e8e7a7fe99ec9fbf801463e8607928322fc5245`

and in the latest
* Version: `kustomize/v4.5.7`
* Git commit: `56d82a8378dfc8dc3b3b1085e5a6e67b82966bd7`


### Reproducing the issue

This folder contains an eensy-weensy, self-contained example to
reproduce the issue.

* `sidecar`. A `Component` to add a container to a `Deployment`.
* `service.chart`. A Kustomization inflating a local Helm chart
   and applying the `sidecar` component. Rendering the Helm chart
   outputs a `Deployment` with a container named `servo`, but the
   additional container `sidecar` is supposed to add never turns
   up in the Kustomize output.
* `service.plain`. A Kustomization applying `sidecar` to the pre-rendered
   Helm chart. This works flawlessly.

The expected output is that you get when building `service.plain`.
This directory comes with a `rendered-chart.yaml` file containing
the chart Helm renders. You can render the chart yourself with this
command:

```bash
$ helm template service.chart/charts/servo \
       --values service.chart/helm-values.yaml \
       > service.plain/rendered-chart.yaml
```

The Kustomization in `service.plain` brings in `rendered-chart.yaml`
as a resource and then includes `sidecar` as a component. This is
what you get when you build

```bash
$ kustomize build service.plain
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: servo
spec:
  replicas: 2
  template:
    spec:
      containers:
      - image: side/car:3.1.5
        name: sidecar
      - image: ser/vo:2.1.7
        name: servo
```

Notice the `Deployment` contains both a container named `servo`,
the one from `rendered-chart.yaml`, and one called `sidecar` which
the `Component` sticks in.

On the other hand, when you build `service.chart`, the `sidecar`
container goes missing

```bash
$ kustomize build --enable-helm service.chart
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: servo
spec:
  replicas: 2
  template:
    spec:
      containers:
      - image: ser/vo:2.1.7
        name: servo
```
