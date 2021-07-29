Let's have a look at the basic information about a *Revision*.
```terminal:execute
command: |-
  kn service create advanced-knative-example --env TARGET=Second --image gcr.io/knative-samples/helloworld-go
  kn revision describe advanced-knative-example-00001
clear: true
```
The key items are the `name` and the `namespace`. By default, the `name` is automatically generated when the *Revision* is created. It doesn’t need to be. You can use kn to create a `Revision` with a name of your own choosing, as the following command shows.
```terminal:execute
command: kn service update advanced-knative-example --revision-name this-is-a-name
clear: true
```
```terminal:execute
command: kn revision list
clear: true
```
Of course, the same can be achieved in YAML by adding the name to the *RevisionTemplateSpec's* metadata. As you may have noticed, if you use the kn CLI to set a *Revision* name, Knative will automatically prefix the name with the *Service*/*Configuration* name and a dash. With YAML you have to add the prefix yourself.
```terminal:execute
command: |-
  kubectl apply -f - << EOF
  apiVersion: serving.knative.dev/v1
  kind: Service
  metadata:
    name: advanced-knative-example
  spec:
    template:
      metadata:
        name: advanced-knative-example-this-too-is-a-name
      spec:
        containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
          - name: TARGET
            value: "Second"
  EOF
clear: true
```
```terminal:execute
command: kubectl get revisions
clear: true
```
When a *Revision* is created, Knative adds additional metadata automatically. If you run the following command, you can for example see the `generateName`, the `generation` and some labels and annotations, which capture a fair amount of useful information.
```terminal:execute
command: kubectl get revision advanced-knative-example-this-too-is-a-name -o json | jq '.metadata'
clear: true
```

Here is a list of important labels and annotations on *Revisions*:
- `serving.knative.dev/configuration` (label) Which *Configuration* is responsible for this *Revision*?
- `serving.knative.dev/configurationGeneration` (label) When the *Revision* was created, what was the current value of generation in the *Configuration* metadata?
- `serving.knative.dev/route` (label) The name of the *Route* that currently sends traffic to this *Revision*. If this value is unset, no traffic is sent.
- `serving.knative.dev/service` (label) The name of the *Service* that, through a Configuration, is responsible for this Revision. When this is blank, there’s no *Service* above the *Configuration*.
- `serving.knative.dev/creator` (annotation) The username responsible for the *Revision* being created. kn and kubectl both submit this information as part of their requests to the Kubernetes API server. Typically, it’s an email address.
- `serving.knative.dev/lastPinned` (annotation) This is used for garbage collection.
- `client.knative.dev/user-image` (annotation) This is the value of the `--image` parameter used with kn service.

If want to create `Revisions` with a name of your own choosing, you have to change the name on every update. So let's revert to the automatic generated names for the rest of the workshop.
```terminal:execute
command: |-
  kubectl delete kservice advanced-knative-example
  kn service create advanced-knative-example --env TARGET=Second --image gcr.io/knative-samples/helloworld-go
clear: true
```

### Container basics
A lot of the information of what you’ll provide to a *Revision* lives in the containers section.
```terminal:execute
command: kubectl get revision advanced-knative-example-00001 -o json | jq '.spec.containers'
clear: true
```
Mostly because of sidecars it's possible to define multiple containers. Because this capability was added later in Knative’s history, it’s slightly inelegant.

### Container images

The container image is the software that ultimately runs on something, somewhere.
I addition to the *image* configuration in the *RevisionSpec* of a *Configuration*, there are two other relevant keys to know about: `imagePullPolicy` and `imagePullSecrets`, which are both optional.
The `imagePullPolicy` setting is an instruction about when to pull an image to a Kubernetes node. 
The `imagePullSecrets` setting refers to a Kubernetes Secret name that contains the credentials to connect to e.g. a private container registry.

*Knative Serving*’s webhook component resolves partial container image names into full names with a digest included. For example, if you told Knative that your container is Ubuntu, it dials out to Docker Hub to work out the full name including the digest (e.g., docker.io/library/ubuntu@sha256:bcf9d02754f659706...e782e2eb5d5bbd7168388b89).
This resolution happens just before the *Revision* gets created because the webhook component gets to act on an incoming *Configuration* or *Service* record before the rest of *Knative Serving* sees these.

You can see the resolved digest in two different ways.
```terminal:execute
command: kubectl get revision advanced-knative-example-00001 -o json | jq '.status.imageDigest'
clear: true
```
```terminal:execute
command: kubectl describe revision advanced-knative-example-00001
clear: true
```

If the specified container image doesn’t have a defined ENTRYPOINT, so that the container runtime can’t find out which command to run by inspecting the container image itself, you are also able to specify `command` and `args`.
kn doesn't expose a way to set a command.

### Environment variables
An easy way to add or change environment variables is to use kn with `--env`.
```terminal:execute
command: kn service update advanced-knative-example --env NAME_OF_A_VARIABLE="OK"
clear: true
```
If you prefer to use YAML, you are able to set the environment variables in the *Configuration* via the *env* property.
```terminal:execute
command: |-
  kubectl apply -f - << EOF
  apiVersion: serving.knative.dev/v1
  kind: Service
  metadata:
    name: advanced-knative-example
  spec:
    template:
      spec:
        containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
          - name: TARGET
            value: "Second"
          - name: NAME_OF_A_VARIABLE
            value: "OK"
          - name: NAME_OF_ANOTHER_VARIABLE
            value: "OK TOO"          
  EOF
clear: true
```
It’s not required to use SHOUTY_SNAKE_CASE for names, but it’s idiomatic.

Remember that *Knative Serving* spits out a new *Revision* every time you touch the template. That includes environment variables, which can be used to change system behavior.

Apart from environment variables that you set yourself, *Knative Serving* injects four additional variables. These are

- `PORT`: The HTTP port your process should listen on. You can configure this value with the ports setting. If you don’t, Knative typically picks one for you. Now, it might be something predictable, like 8080, but that is not guaranteed. For your own sanity, only listen in on the port you find in PORT
- `K_REVISION`: The name of the *Revision*. This can be useful for logging, metrics, and other observability tasks
- `K_CONFIGURATION`: The name of the *Configuration* from which the *Revision* was created
- `K_SERVICE`: The name of the *Service* owning the *Configuration*. If you are creating the *Configuration* directly, there will be no *Service*. In that case, the `K_SERVICE` environment variable will be unset

As with pods there are actually two alternative ways of injecting environment variables: `envFrom` and `valueFrom` for values that come from either a ConfigMap or a Secret.
The kn cli supports injecting environment variables from ConfigMaps or Secrets via the `--env-from` option
```terminal:execute
command: |-
  kubectl apply -f - << EOF
  ---
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: example-configmap
  data:
    foo: "bar"
  ---
  apiVersion: v1
  kind: Secret
  metadata:
    name: example-secret
  type: Opaque
  data:
    password: c2VjdXJl
  EOF
  kn service update advanced-knative-example --env-from config-map:example-configmap --env-from secret:example-secret
  kubectl describe kservice advanced-knative-example
clear: true
```
### *Configuration* via files

Passing configuration via the command line is easy: use `args`. Via the environment is also easy: use `env` or `envFrom`. But these options have two problems:
1. Some software requires parameter files, or you might prefer parameter files over other possibilities. For these cases the command line and environment variables won’t do
2. Command lines and environment variables aren’t a safe place for secrets to hang out. Too many tools and systems have some way of laying eyes on a command line or an environment variable

One way out of this is to take your Secrets and ConfigMaps and expose these as files in a filesystem. This first of all enables grumpy old software the luxury of not changing. Secondly, it behaves like a filesystem, adding another permissions hoop attackers will need to hop through. Finally, these get mounted as tmpfs volumes. Your sensitive keys and values never touch a disk and become inaccessible once the container goes away.

Let’s start with the kn-centric view of things by mounting a Secret into our container.
```terminal:execute
command: kn service update advanced-knative-example --mount /my-dir=secret:example-secret
clear: true
```
The key is the `--mount` parameter, which maps from example-secret into /my-dir. The secret: prefix tells kn what kind of record it will ask Knative to map, the alternative option is configmap: for ConfigMaps.

To see if it worked, we have to have a look at the YAML with kubectl, because that information is not part of the information we get with `kn revision describe`.
```terminal:execute
command: kubectl get kservice advanced-knative-example -o yaml 
clear: true
```
You can see that the configuration is in two places: `volumeMounts` and `volumes`.
As well as `--mount`, you’ll find there’s a `--volume` option. The help text for both is close to identical. So which should you use? You should stick to `--mount`. It does more or less what one might expect in terms of creating a directory, putting ConfigMaps and Secrets onto a volume, and then mounting it for you.

### Probes

In raw Kubernetes, you are given the ability to set `livenessProbes` and `readinessProbes` on your containers. When liveness checks fail, Kubernetes eventually kills the container and relaunches it someplace else. When readiness checks fail, Kubernetes prevents network traffic from reaching the container. 

Knative exposes this functionality, but with caveats.
Knative takes control of the port value to satisfy its "Runtime Contract." It modifies any probes so that their port value is the same as the port value of the container itself, which will be the same as the `PORT` environment variable that’s injected.

If you don’t provide one or both probes, *Knative Serving* creates `tcpSocket` probes with `initialDelaySeconds` set to zero. By setting these to zero, Knative is telling Kubernetes to immediately begin checking for liveness and readiness in order to minimize the time it takes for an instance to begin serving traffic.

The kn cli doesn't have an option for setting or updating probes, so you have to do it via YAML if you have a proven need to adjust the defaults.

### Setting consumption limits

Knative lets you set minimum and maximum levels for CPU share and bytes of RAM via kn cli and YAML. This is another case of directly exposing the underlying Kubernetes feature, which is called resources.
```terminal:execute
command: kn service update advanced-knative-example --request cpu=500m,memory=128Mi
clear: true
```
The upper ceiling is known as limits and follows the same format as requests. The following kn listing illustrates setting limits.
```terminal:execute
command: kn service update advanced-knative-example --limit cpu=750m,memory=256Mi
clear: true
```

### Container concurrency
The purpose of the *Autoscaler* is to ensure that you have enough instances of a *Revision* running to serve demand. One meaning of enough is to ask, "How many requests are being handled concurrently per instance?"

Which is where `containerConcurrency` comes in. It’s your way of telling Knative how many concurrent requests your code can handle. If you set it to 1, then the *Autoscaler* will try to have approximately one copy serving each request. If you set it to 10, it will wait until there are 10 concurrent requests in flight before spinning up the next instance of a *Revision*. 

You can set a concurrency limit with kn CLI or YAML.
```terminal:execute
command: kn service update advanced-knative-example --concurrency-limit 1
clear: true
```

There is also another option, `--concurrency-target`, but this works differently. Instead of setting a maximum level of concurrency, it sets a desired level of concurrency. Right now you can use `--concurrency-limit`, and Knative sets `--concurrency-target` to the same level.
There isn’t an equivalent in the YAML for `--concurrency-target`, for `--concurrency-limit` it's `containerConcurrency`.
```terminal:execute
command: |-
  kn service delete advanced-knative-example
  kubectl apply -f - << EOF
  apiVersion: serving.knative.dev/v1
  kind: Service
  metadata:
    name: advanced-knative-example
  spec:
    template:
      spec:
        containerConcurrency: 10
        containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
          - name: TARGET
            value: "Second"        
  EOF
clear: true
```
If you don’t use `--concurrency-limit` or set `containerConcurrency` in YAML, the value defaults to 0. Leaving it unset (i.e., leaving it at 0) is basically okay.

### Timeout seconds

*Knative Serving* is based on a synchronous request-reply model, so as a matter of necessity, it needs timeouts. The `timeoutSeconds` setting lets you define how long *Knative Serving* will wait until your software begins to respond to a request.

The default value is 5 minutes. More specifically, 300. 
On the upside, the default value is pretty much guaranteed to avoid flakiness due to slow responses. On the downside, if you have a bug that causes stalled responses, you’re going to see the Autoscaler busily stamping out copies as unattended requests pile up.

This setting is not directly surfaced through kn and, instead, has to be set using kubectl apply. 
Out of the box, you can set values up to 600 (10 minutes). Knative Serving’s timeout limit can be raised by tinkering with the installation configuration. 

```terminal:execute
command: |-
  kubectl apply -f - << EOF
  apiVersion: serving.knative.dev/v1
  kind: Service
  metadata:
    name: advanced-knative-example
  spec:
    template:
      spec:
        timeoutSeconds: 150
        containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
          - name: TARGET
            value: "Second"        
  EOF
clear: true
```

To clean up the environment for the next section run:
```terminal:execute
command: kn service delete advanced-knative-example
clear: true
```