## Deployment patterns

In the following section let's talk about deployment patterns to reduce the risk of introducing new features. They allow you a more effective feature-feedback loop before rolling out the change to your entire user base.

### The Blue/Green deployment
You have a version of your software already running and serving traffic. Let’s call this "Blue".
You now want to deploy a new version of your software. Let’s call it "Green".
A first approach might be to stop Blue, then deploy Green. The time between "Stop Blue" and "Start Green" is scheduled downtime.

Scheduled downtimes are still downtimes. It would be nice if we didn’t have to stop Blue first. And, thanks to the magic of load balancers and proxies and gateways and routers, we don’t have to. 

What we do instead is:
1. Start "Blue"
2. Switch traffic from "Blue" to "Green"
3. Stop "Blue"

Upgrades without taking a scheduled downtime is the basic motivation for Blue/Green deployments. But there are other benefits. One is that we can now ensure Green is good before we switch to Blue. Or, alternatively, if Green is bad, we can more easily roll the system back to Blue because our muscle for switching traffic is well-developed. To ensure rollbacks are fast, we can keep Blue running for a little while until Green has proved itself worthy of our trust.

### The Canary deployment
In a Canary deployment, we actually roll out a reduced-size sample of Green to run alongside Blue.
Instead of cutting all traffic over to Green, we instead send a fraction of requests to it and see what happens. Then we might raise the number of Green copies. If we’re satisfied with how these run, we then proceed to fully deploy Green. We then cut over and immediately remove Blue. After all, our canaries established that Green was safe, so rollback speed is a less critical consideration.

### Progressive deployment
In progressive deployment, we keep the consumption level much closer to steady state. Say we have 100 instances of Blue. We first perform a Blue/Green deployment of a single instance instead of our entire system. Afterward, we have 99 Blue and 1 Green. We run this 1 Green as a canary for a while. If we’re happy, we perform another Blue/Green deployment, this time for 9 instances. Afterward, there are 90 Blue and 10 Green. Then, finally, we might complete the rollout of Green, retiring Blue as we go.

### Supported deployment patterns in *Knative Serving*
So what does *Knative Serving* do? Blue/Green? Canary? Progressive? The answer is: all of these. Sort of.
*Knative Serving* sets out to answer these with two core types: the *Configuration* and the *Revision*. The connection is that each *Revision* is a snapshot of a *Configuration*, and a *Configuration* is the template for the most recent *Revision*. 

*Revisions* represent snapshots of *Configurations* over time, giving a partial history of your system.
Multiple *Revisions* can receive traffic for a single endpoint. This allows the Blue/Green, Canary, and progressive deployment patterns.

## The anatomy of *Services* and *Configurations*
A *Configuration* is a definition of your software. I wanted to show you kn first and avoid being too Kubernetes-centric. But now it will be easiest to explain *Configurations* by using the YAML form.

To ease the transition, the following listing shows the kn command we used.
```
kn service create intro-knative-example --image gcr.io/knative-samples/helloworld-go --env TARGET="First"
```
and here is the equivalent *Configuration* YAML file
```
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: intro-knative-example
spec:
  template:
    spec:
      containers:
      - image: gcr.io/knative-samples/helloworld-go
        env:
        - name: TARGET
          value: "First"
```
Everything from the kn CLI is present in the YAML version. We have a name, a container, and an environment variable.
This document isn’t meant to be used by kn, it would typically be submitted to Kubernetes using `kubectl create` or `kubectl apply`.
The template is actually a *RevisionTemplateSpec* and the innermost spec is a *RevisionSpec*. It is converted into *Revisions* and changing the template is what causes the creation of Revisions.

Let's now create the first revision of a service/configuration via a YAML document. In this case we are redirecting the YAML document content input into the interactive shell command. In most cases you would instead create a file of type yaml and apply it via e.g. `kubectl apply -f advanced-knative-example.yaml`
```execute
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
          value: "First"
EOF
```
After the document with our configuration is applied, we can check the created service ...
```terminal:execute
command: kubectl get kservice
```
... , configuration ... 
```terminal:execute
command: kubectl get configurations
```
..., and revision.
```terminal:execute
command: kubectl get revisions
```
In this case we are using kubectl commands for it, but you are also able to use the kn equivalents.

Let's now update our configuration by changing the ENV variable to the value "Second".
```execute
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
EOF
```
Now you can see two Revisions, but there is still only one *Service* and *Configuration* with the name advanced-knative-example
```terminal:execute
command: kubectl get kservice,configurations
```
```terminal:execute
command: kubectl get revisions
```
### *Services* and *Configuration* status
There is also a `status` section in the *Service* and *Configuration* Kubernetes objects, that is set by the service and configuration *Reconcilers*. 
Let's use kubectl to display the *Service* status:
```terminal:execute
command: kubectl describe kservice advanced-knative-example
```
You can see two basic sets of information. The first is conditions, which I will talk about more later (during the discussion of *Revisions*). The second set of information is the trio of `Latest Created Revision Name`, `Latest Ready Revision Name`, and `Observed Generation`.

Let’s start with **Observed Generation**. Earlier you saw that each *Revision* is given a generation number. It comes from Observed Generation. When you apply an update to the *Configuration*, the Observed Generation gets incremented. When a new *Revision* is stamped out, it takes that number as its own.

**Latest Created Revision Name** and **Latest Ready Revision Name** are the same here, but need not be. Simply creating the *Revision* record doesn’t guarantee that some actual software is up and running. These two fields make the distinction. In practice, it allows you to spot the process of a *Revision* being acted on by lower-level controllers.

On the *Service* status you can additionally see information regarding the traffic split.

These fields are useful for debugging. 

To clean up the environment for the next section run:
```terminal:execute
command: kn service delete advanced-knative-example
clear: true
```