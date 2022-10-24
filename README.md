Anubis deployment playground
----------------------------
> taking Anubis from the underworld up to the clouds!

This repo is a playground to explore ideas for [Anubis][anubis] cloud
deployment. There's a proof-of-concept Kustomize-based K8s deployment
in this repo at the moment. It's fully functional but ain't pretty.
We'll improve on that in the future and maybe also consider other
avenues for comparison—e.g. an Istio-based deployment or a K8s admission
controller.

Anubis is a security policy enforcement service that hooks into the
OPA policy evaluation loop. To protect a service with Anubis, a service
sidecar deployment is needed where an Envoy proxy (the sidecar) intercepts
HTTP requests to the service, forwards them to OPA, OPA evaluates security
policies and only if the policies allow it, does Envoy finally forward
the original request to the service.

Our goal here is to develop a K8s deployment pipeline through which
we can:

* configure OPA and Envoy to work with Anubis;
* pair an Envoy proxy with each service to protect;
* configure each proxy to use OPA as an external authorisation provider;
* optionally make Envoy pre/post-process requests/responses through
  service-specific Lua scripts. (Each service can use its own script.)


### Proof-of-concept

We've developed a Kustomize solution to do the job. In a nutshell,
for each service to protect, we take its base deployment and tweak
it to inject an Envoy sidecar with all the required config. This is
done through a YAML processing pipeline—see the sections below for
the details. The UML composite structure diagram below details what
a service deployment looks like in K8s after applying the YAML Kustomize
outputs.

![Service deployment with Envoy sidecar.][dia.routes]

Traffic gets routed as follows. When an HTTP request hits the service
API, it gets routed to the Envoy proxy running alongside the service.
Envoy then forwards the request to OPA which evaluates a Rego policy
and tells Envoy whether or not the policy allowed that request to go
on. If allowed, Envoy forwards the request to the service's API on
localhost, otherwise it returns the client a fat "403 Forbidden".
Plus, each service deployment can specify a custom Lua script to
intercept service requests and responses that Envoy runs on each
HTTP message exchange.

Our proof-of-concept deployment demoes this security flow with a
couple of services. We've got Orion and Quantum Leap with their
backing DBs, Mongo and Crate, respectively. Both Orion and Quantum
Leap sit behind their own Envoy proxy, configured to let OPA decide
on security. OPA is configured with a trivial policy that allows a
request only if the request contains a `fiware-service` header with
a value of `goodfellas`. (Sorry for the dark humour :-)
Finally, the Quantum Leap deployment plugs in its own Lua script
to sneak a custom header in to the service response before it gets
returned to the client: `greeting: howzit!`.


### Test-driving the PoC

Time to take our proof-of-concept deployment for a spin. You'll need
a K8s cluster and some tools on your box before you can play. Follow
the steps below.

#### K8s cluster
If you already have a K8s test cluster you can deploy our PoC to,
just skip to the next section. Otherwise read on, we'll build one
on your box.

While there's many ways to get a K8s cluster running on your box,
we'll do it with a Multipass VM. First step is to install Multipass
(version >= 1.8), then spin up a 20.4 Ubuntu VM like this

```bash
$ multipass launch --name anubis --cpus 2 --mem 4G --disk 20G 20.04
$ multipass shell anubis
```

Install MicroK8s (upstream Kubernetes 1.21)

```bash
$ sudo snap install microk8s --classic --channel=1.21/stable
```

Add yourself to the MicroK8s group to avoid having to `sudo` every
time your run a `microk8s` command

```bash
$ sudo usermod -a -G microk8s $(whoami)
$ newgrp microk8s
```

and then wait until MicroK8s is up and running

```bash
$ microk8s status --wait-ready
```

Finally bolt on DNS and local storage

```bash
$ microk8s enable dns storage
```

Wait until all the above extras show in the "enabled" list

```bash
$ microk8s status
```

Now we've got to broaden MicroK8s node port range. This is to make
sure it'll be able to expose any K8s node port we're going to use.

```bash
$ nano /var/snap/microk8s/current/args/kube-apiserver
# add this line
# --service-node-port-range=1-65535

$ microk8s stop
$ microk8s start
```

Almost done. Copy out the cluster credentials to a local file `k8s-cfg.yaml`
and exit the VM.

```bash
$ cat /var/snap/microk8s/current/credentials/client.config
$ exit
```

The `k8s-cfg.yaml` file should look something like this:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: wada0wada
    server: https://127.0.0.1:16443
  name: microk8s-cluster
contexts:
...
```

Replace `127.0.0.1` with the IP address of your VM as output by
this command

```bash
$ multipass list
```

Finally tell `kubectl` to use this config so you can play with
our freshly mint cluster from your local terminal.

```bash
$ export KUBECONFIG=$(pwd)/k8s-cfg.yaml
```

#### Local tools
You should install these tools on your box:

* kubectl `1.22`
* kustomize `4.4.0`
* helm `3.7.1`
* opa `0.36.1`
* argocd `2.1.15`

Compatible versions should do too. If you don't want to pollute your
global environment, install them through [Nix][nix] and use our virtual
env instead. Here's how. First install Nix

```bash
$ sh <(wget -qO- https://nixos.org/nix/install)
$ mkdir -p ~/.config/nix
$ echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Then simply

```bash
$ cd nix
$ nix shell
```

and voila, you're in a virtual env with all the tools you need at
the exact same versions we used. Sweet.

#### Deployment
After toiling away at prep steps, we're ready to deploy our PoC.
First off, let's deploy storage, backing DBs and OPA

```bash
$ kustomize build k8s/infra | kubectl apply -f -
```

Then the two services we're going to use for testing our setup,
Quantum Leap and Orion.

```bash
$ kustomize build k8s/apps/quantumleap | kubectl apply -f -
$ kustomize build --enable-helm --load-restrictor LoadRestrictionsNone \
            k8s/apps/orion.oc | kubectl apply -f -
```

Notice each Kustomize build injects a separate Envoy sidecar in the
`Deployment` resource, so for both Quantum Leap and Orion K8s should
report a pod container count of 2.

```bash
$ kubectl get pod
NAME                           READY   STATUS    RESTARTS   AGE
mongodb-6dd4bf78d9-s6qlj       1/1     Running   0          56s
crate-0                        1/1     Running   0          49s
opa-6888445484-vkqsz           1/1     Running   0          37s
quantumleap-747bd56fc5-g4cjl   2/2     Running   0          18s
orion-orion-65d5c9d9d-m8mgk    2/2     Running   0          12s
```

#### Showtime
Let's have some fun now. In the commands that follow, replace the
IP address in the URL with the external IP of your cluster.

Calling Quantum Leap without a `fiware-service` header should make
OPA very unhappy

```bash
$ curl -v 192.168.64.27:8668/version
> GET /version HTTP/1.1
> Host: 192.168.64.27:8668
> User-Agent: curl/7.64.1
> Accept: */*
>
< HTTP/1.1 403 Forbidden
< greeting: howzit!
< date: Mon, 17 Oct 2022 09:05:38 GMT
< server: envoy
< content-length: 0
```

But if we pass in the right header, OPA should let us through

```bash
$ curl -v 192.168.64.27:8668/version -H 'fiware-service: goodfellas'
> GET /version HTTP/1.1
> Host: 192.168.64.27:8668
> User-Agent: curl/7.64.1
> Accept: */*
> fiware-service: goodfellas
>
< HTTP/1.1 200 OK
< server: envoy
< date: Mon, 17 Oct 2022 09:03:57 GMT
< content-type: application/json
< content-length: 29
< x-envoy-upstream-service-time: 23
< greeting: howzit!
<
{
  "version": "0.8.3-dev"
}
```

For good measure, let's also try a `fiware-service` header with a
value other than `goodfellas`

```bash
$ curl -v 192.168.64.27:8668/version -H 'fiware-service: shadydeals'
> GET /version HTTP/1.1
> Host: 192.168.64.27:8668
> User-Agent: curl/7.64.1
> Accept: */*
> fiware-service: shadydeals
>
< HTTP/1.1 403 Forbidden
< greeting: howzit!
< date: Mon, 17 Oct 2022 09:05:26 GMT
< server: envoy
< content-length: 0
```

Notice that `greeting: howzit!` header we get back in each and every
response, regardless of authorisation success or failure. That's the
header the Lua filter linked to the Quantum Leap deployment outputs.

Cool bananas! Calling Orion should get you similar responses. Try
this yourself

```bash
$ curl -v 192.168.64.27:1026/version
$ curl -v 192.168.64.27:1026/version -H 'fiware-service: goodfellas'
$ curl -v 192.168.64.27:1026/version -H 'fiware-service: shadydeals'
```

There should be no custom response header of `greeting: howzit!` for
Orion though. That's because that Lua script we talked about earlier
is private to the Quantum Leap deployment. Also, the Orion deployment
doesn't plug in any Lua script.


### YAML pipeline concept

We've implemented a YAML processing pipeline to build the K8s descriptors
that ultimately declare the desired cluster state. This pipeline calls
Helm to pull charts from remote repos and then substitutes our local
Helm values into the collected chart templates to generate base K8s
descriptors. The next pipeline step tweaks these base descriptors to
get the final descriptors to be fed into the K8s API. Tweaking happens
by applying our Kustomize patches to the base descriptors.

From a conceptual standpoint, it helps to think of the whole process
in terms of tree transformations. Think of a YAML doc as a tree whose
nodes hold text. Then pulling a chart results in a template tree. A
local Helm value file specifies which nodes in the template tree to
fill along with their content. So the substitution step just swaps
the template placeholders with the nodes in the value file to get a
base tree. Similarly, a Kustomize patch is a tree that shares a path
from the root with the base tree and can replace nodes in that path,
add new ones or even remove nodes from the base tree. Applying a patch
merges the patch tree into the base by adding, replacing or deleting
nodes as needed. After applying all the patches we finally get the
K8s descriptor tree to input into the K8s API. A bit of a hand-wavy
explanation of what's going on under the bonnet? Sure thing, but good
enough as a first approximation. Anyhoo, here's a visual to sum it
all up.

![Kustomize pipeline model.][dia.pipeline]

For a concrete example, look in [k8s/apps/orion.oc][k8s.orion.oc].
There we pull down the Orion chart from the [Orchestra Cities repo][oc.charts],
render it with a local value file, then patch the output to get the
final YAML we need for deployment. Keep in mind starting from a Helm
chart isn't a requirement. It's perfectly fine to use your own base
YAML or even make Kustomize fetch it from the inter webs—e.g.
[k8s/apps/quantumleap][k8s.quantumleap] starts from a local base.


### YAML pipeline implementation

We've developed the whole pipeline with Kustomize. The "Kustomization
code" boils down to a bunch of build declarations in YAML files we
keep in the `k8s` dir. The `infra` subdir contains the code to set
up OPA, backing DBs and some convenience volumes for permanent pod
storage, as well as a shared sidecar injection Kustomize component.
The OPA setup is kinda straightforward with the service delegating
policy decisions to the Rego code in `k8s/infra/security/rego`. There's
two Rego modules in there to show how we could keep the Rego policies
modular—pun intended. We mount each module on the OPA pod, so module
import within the OPA service's evaluation loop works just like it
does when you develop locally, using the `opa` command. The `apps`
subdir of `k8s`, contains the code to deploy application services.

Sidecar injection works by adding an Envoy container to a service
pod. The injection patch also takes care of mounting a sane, but
opinionated Envoy config on the pod and starting Envoy with that
config. Injecting a sidecar into a `Deployment` takes a couple of
lines of YAML:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Assuming this was your service's Kustomization file in
# k8s/apps/your-service, you'd add these two lines:

components:
- ../../infra/sidecar
```

Have a read through the docs in `k8s/infra/sidecar` to find out how
to add your own Lua script or how to use your own Envoy config if
our one doesn't float your boat. In fact, to keep things simple,
our built-in Envoy config makes a couple of assumptions about the
service you want to add a sidecar to:

* the HTTP server listens on port 8080;
* the `Service` descriptor forwards traffic to the pod on port
  8181—that's where the injection code places Envoy;
* OPA is reachable at `opa:9191`.

If you write the `Service` and `Deployment` descriptors yourself
there's no prob meeting the requirements, but if you source that
YAML from somewhere you'll typically have to tweak it to set the
right ports. The good news is that these are all easy tweaks you
can do with Kustomize—for examples, look in the `orion.oc` and
`quantumleap` dirs. But if you'd rather not do that, well, you
can still override our built-in Envoy config with your own quite
easily.

One last thing about required Kustomize flags. We trigger the Helm
processing of charts from Kustomize so you've got to make sure Kustomize
can get hold of the Helm binary. If Helm is not in your `PATH`, you'll
have to tell Kustomize where to find it—use the `--helm-command` flag
for that. Also, our pipeline relies on Helm generators so you've got
to pass the `--enable-helm` flag to the build command, e.g.

```bash
$ kustomize build --enable-helm k8s/apps/orion.oc
```

How would that work with ArgoCD? Luckily you can configure Argo CD
to call Kustomize with the flags we need—hear it straight from the
[horse's mouth][argocd.kust-w-helm].

#### NOTE. Kustomize issue.
At the moment we're having an issue with Kustomize where the sidecar
component patch doesn't get applied when using `helmChart` generators.
As a workaround, you've got to pass this additional flag to the build
command: `--load-restrictor LoadRestrictionsNone`. Hopefully, this is
just a stopgap fix which won't be needed going forward. See:
- https://github.com/kubernetes-sigs/kustomize/issues/4841




[argocd.kust-w-helm]: https://github.com/argoproj/argo-cd/issues/7835
[anubis]: https://github.com/orchestracities/anubis
[dia.pipeline]: ./kustomize-pipeline.svg
[dia.routes]: ./net-routes.svg
[nix]: https://nixos.org/learn.html
[oc.charts]: https://github.com/orchestracities/charts
[k8s.orion.oc]: ./k8s/apps/orion.oc/kustomization.yaml
[k8s.quantumleap]: ./k8s/apps/quantumleap/kustomization.yaml
