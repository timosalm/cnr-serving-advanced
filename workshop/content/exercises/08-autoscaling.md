Let's now have a look at the basic structure and functioning of the components responsible for the management of scaling in *Knative Serving*: the *Autoscaler*, the *Activator*, and the *Queue-Proxy*. 

As a problem, autoscaling is easy to describe. You have demand. You want to serve that demand. You obtain some amount of capacity to serve the demand. You would like the business of calculating and obtaining capacity to be automated.

Sometimes, you would like the calculations and capacity provisioning steps to be done ahead of anticipated demand (usually called predictive autoscaling), and sometimes you want the decisions to be made on short notice according to current conditions (reactive autoscaling). *Knative’s Pod Autoscaler (KPA)* is classified as a reactive autoscaler.

The tricky problem is scaling down to zero and scaling up from zero. 
To achieve this, the software must be able to buffer traffic when there are no instances. Yout must be able to observe demand—traffic—in order to make sensible scaling decisions. Once it has made such decisions, it must ensure that buffered traffic doesn’t overwhelm instances. The problem for Knative is to deal with the autoscaling problem sensibly, subject to these basic constraints:
- End users should not see an error just because there are no running copies of software
- Software should not be overwhelmed by demand
- The platform shouldn’t waste resources unnecessarily

When there are no instances, the **Activator** becomes the target for any traffic that will arrive. Yout will buffer the requests and then pokes the **Autoscaler**, that makes a scaling decision to scale up to 1. After the *Revision* instance is available, the *Activator* then forwards the requests it buffered to that instance. The *Revision* instance sends its response, which then flows from the *Activator*, through the gateway, to the user.
The *Activator* decides whether to remain on the data path based on how many requests it thinks available instances can actually service and the responsibility for buffering requests then falls on the *Queue-Proxy*.

The **Queue-Proxy** is a sidecar container. When you submit a *Service* or Configuration, Knative adds the *Queue-Proxy* to the Pod specification that it ultimately sends to Kubernetes on your behalf. 

If many requests show up in a short time, the *Autoscaler* panics. The *Autoscaler* typically makes its decisions based on a trailing average of the past 60 seconds. Youn panic mode, this drops to 6 seconds. This makes the *Autoscaler* more sensitive to bursty traffic.
In panic mode the *Autoscaler* simply ignores any decision to scale down until the panic is over.

### Configuring autoscaling
The *Autoscaler* can receive configurations via a number of options. 
One such option is to create a Kubernetes ConfigMap record in the `knative-serving` namespace, named `config-autoscaler`. 
Autoscaling configurations you define this way are global and will affect everyone using this Kative installation.
A second option for setting configurations is via annotations. 

Let's first create a new service.
```terminal:execute
command: kn service create advanced-knative-autoscaling-example --image gcr.io/knative-samples/helloworld-go --env TARGET="First"
clear: true
```

#### Setting scaling limits
Scale to zero is enabled by default, but you don't always need it. To disable it for all applications, which you don't want to do in most of the cases, you can apply the following configuration via the ConfigMap option, but in this workshop it's not allowed because it will affect any workshop session.
```
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-autoscaler
  namespace: knative-serving
data:
  enable-scale-to-zero: 'false'
EOF
```
The alternative is setting a `/minScale` annotation on a *Service* or a *Revision*.
For a *Revision* you can do that with the kubectl CLI, but because the annotation has to be set in the *RevisionTemplateSpec* it's not possible to set it via `kubectl annotate kservice`.
```terminal:execute
command: kubectl annotate revision advanced-knative-autoscaling-example-00001 autoscaling.knative.dev/minScale=1
clear: true
```
```terminal:execute
command: kn revision describe advanced-knative-autoscaling-example-00001
clear: true
```
As an alternative, you can set the annotation for a *Service* in *RevisionTemplateSpec* via YAML.
```terminal:execute
command: |-
  kubectl apply -f - << EOF
  apiVersion: serving.knative.dev/v1
  kind: Service
  metadata:
    name: advanced-knative-autoscaling-example
  spec:
    template:
      metadata:
        annotations:
          autoscaling.knative.dev/minScale: "2"
      spec:
        containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
          - name: TARGET
            value: "First"
  EOF
clear: true
```

Another option is to set the annotation via the kn CLI.
```terminal:execute
command: kn service update advanced-knative-autoscaling-example --annotation autoscaling.knative.dev/minScale=0
clear: true
```

Additionally, the minimum and maximum(`/maxScale` annotation) scale options are sufficiently likely to be used that kn allows you to set these at creation time or when updating a *Service* with `--min-scale` and `--max-scale`.
```terminal:execute
command: kn service update advanced-knative-autoscaling-example --min-scale 1 --max-scale 5
clear: true
```

#### Setting scaling rates
There’s a limit to how fast a cluster can respond to *Autoscaler* desires, whether scaling up or down. 
Scaling up is governed by `max-scale-up-rate`, which defaults to 1,000. Yout allows the *Autoscaler *to jump in multiples of up to 1,000 times at each decision point, but only from the actual currently running instances. 
So for example, if there are two instances, this limit allows the *Autoscaler* to jump by 2,000. 
The scaling down is governed by `max-scale-down-rate`, for which the default is 2. 

Another setting affecting scale-down behavior is `scale-to-zero-grace-period`, which defaults to 30 seconds. 
When Knative decides to scale to zero, this grace period is how long Knative is prepared to wait for networking systems to unplug the instance from a network before Knative asks Kubernetes to kill it. 

As these three settings can only be set on the ConfigMap, these apply to the entire installation.

#### Setting target values
Two magic numbers have an outsized influence on the *Autoscaler*: `container-concurrency-target-default` (default value 100, the annotation is `/target`) and `container-concurrency-target-percentage` (default value 70, the annotation is `/targetUtilizationPercentage`). 
These are the values that determine the ratio of requests to instances that the Autoscaler tries to maintain. 
The basic logic is that `-default` ultimately gets treated as the maximum possible value for concurrent requests for any one instance, while `-percentage` is used to calculate the actually desired value for concurrent requests for each instance on average.
The practical upshot is that, out of the box, the *Autoscaler* targets 100 * 0.7 concurrent requests per instance: 70, in other words.

And this is what `-target-default` is about. You can set `containerConcurrency`for your *Service* or *Configuration*, and it will show up on a *Revision*. But if you don’t do that, then *Knative Serving* needs to pick something as an upper limit. 

You can configure the *Autoscaler* to use requests per second (RPS) as the scaling metric.
First, if you want to set it globally, you can configure `requests-per-second-target-default` in the ConfigMap, implicitly switching the autoscaler to use RPS as its scaling metric. 
You can’t use the `container-concurrency-target-default` key as well, though, because these options are mutually exclusive.
Second, if instead you want to switch to RPS-based scaling on a particular *Service* or *Revision*, you need to attach two annotations: `/metric` and `/target`. 
The `/metric` annotation explicitly sets the scaling metric. 
You can set it to concurrency, which gives you the normal behavior, or to rps for RPS-based scaling. 
The `/target` annotation is a number of requests, interpreted differently according to the `/metric` that you set. 
For concurrency, `/target` means the number of concurrent requests, and for rps, it means the number of requests per second.

#### Setting decision intervals
The *Autoscaler* surveys the world and renders judgement on a regular 2-second interval. 
This is configurable in the ConfigMap by setting the tick-interval key. 
Lowering this interval means that the Autoscaler makes more frequent, perhaps more timely, decisions at the expense of greater thrashing and operational overhead. 
Increasing the interval spares resources, but makes the system more sluggish when responding.

### Setting window size
And speaking of accumulating data, it’s possible to adjust the all-important window sizes. First is the stable window, defaulting to 60 seconds. Shortening this window makes the Autoscaler more jittery - it reacts more to what might be random fluctuations in demand. Making it longer smooths reactions, but means that sustained increases or decreases in demand might not be heeded as quickly.

Unlike tick-interval, which is a global setting that is hard to tune for everyone, it’s possible to set the stable window either globally (using stable-window on ConfigMap) or on your own *Service* or *Configuration*. To do this, you set a `/window` annotation. The format here is Golang’s shorthand for units of time. For example, 60s and 1m will be considered the same, but you need to identify the unit of time (s = second, m = minute, etc.) in order to provide a valid value.
You should absolutely be open to tuning this value using the annotation if it makes sense for your workload. The balance here is between jitteryness and smoothness.

The panic window is not defined directly, it’s defined as a percentage of the stable window. You can set this percentage globally with `panic-window-percentage` or use the `/panicWindowPercentage` annotation on a *Service* or *Configuration*. The default is 10%, which is how the panic window comes out to being 6 seconds by default.

### Setting the panic threshold
The other major knob to twist for panic behavior is the panic threshold. You can set this globally with `panic-threshold-percentage`, but you probably shouldn’t. But there can be a case for adjusting it for individual *Services* or *Configurations*, for which you can use the `/panicThresholdPercentage` annotation.

### Setting the target burst capacity
The target burst capacity (TBC) subsystem is mostly about the ratios at which the *Activator* stays in the data path or steps out of it. The name comes from the idea that the *Activator* needs to understand how much capacity the current instances will be able to safely absorb in a "burst" so that it can decide whether it should stay in the data path as a buffer.

This can be set globally with `target-burst-capacity`, or on a *Service* or *Configuration* with `/targetBurstCapacity`. The calculation is fiddlier to describe than you would like, but there are a few key values:
- 0 means "only use the Activator when my software scales to zero."
- -1 means "always use the Activator, regardless of scale."
- Other positive values represent a fixed target of "burst capacity."

The default is 200. The *Activator* will only begin to back out of the data path if it calculates that there is a "spare" 200 request capacity available. Youn general, this will be truer of larger pools of instances, so the *Activator* in this respect more or less works in line with the square root staffing rule.

### Other autoscalers
The *Knative Pod Autoscaler* isn’t the only autoscaler you can use with Knative Serving, it’s just the one you get by default. Out of the box, you can also use the Horizontal Pod Autoscaler (HPA), which is a subproject of the Kubernetes project. The HPA was originally built around using CPU load as its scaling target but has lately grown to be more featuresome. If you have already built tooling and know-how around the HPA, don’t be shy about using it.
The Vertical Pod Autoscaler (VPA) is not directly supported and doesn’t really fit the way Knative thinks anyhow. The Kubernetes Event-Driven Autoscaler, aka KEDA, works on what is arguably a sounder principle, but integration with Knative is currently only at an experimental stage.

To clean up the environment if you want to jump to another section run:
```terminal:execute
command: kn service delete advanced-knative-autoscaling-example
clear: true
```