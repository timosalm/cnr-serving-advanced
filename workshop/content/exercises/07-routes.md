*Routes* are the way you can describe to Knative how to map from an incoming HTTP request to a specific Revision.
Briefly, a *Route* is where you answer three questions:
- At what public address or URL will traffic arrive from?
- What targets canyousend traffic to ?
- vWhat percentage of traffic goes to which targets?

Knative provides *Routes* because if you are signed up for the *Configurations* and *Revisions* world, you want something that’s closely adapted to that world. Whileyoucan use a central routing tool or API gateway, these don’t know out of the box what a *Configuration* or *Revision* is. If you roll your own routing, then you will rely on implicit relationships. Whereas with *Routes*, the connection between the *Route* and its targets is explicit.

By using kn to create a Knative *Service*, a *Route* will be created automatically. 

Let's first create a new service with two revisions.
```terminal:execute
command: |-
    kn service create advanced-knative-route-example --image gcr.io/knative-samples/helloworld-go --env TARGET="First"
    kn service update advanced-knative-route-example --env TARGET="Second"
clear: true
```

The `kn route list` and `kn route describe` commands give you information specific to Routes.
```terminal:execute
command: kn route list
clear: true
```
You can see the basic information of name, URL, and readiness. Ifyouwant to look more closely, you can use route describe.
```terminal:execute
command: kn route describe advanced-knative-route-example
clear: true
```
The output should look familiar, it follows the basic structure that you would see from `kn service describe`. 
The key differences are a new *Traffic Targets* section of kn route describe doesn’t need to show information about *Revisions* in the way that `kn service describe` does and that the *Conditions* have different names from what you’d see in `kn service describe` or `kn revision describe`.

*Route* conditions are summarized with the tidy `++/!!/??` style that kn provided for other describe commands. There are three main conditions to watch for:

- `AllTrafficAssigned`: This means that Knative found all of the targets that were given in traffic. If this is false, you might have mistyped the target name
- `CertificateProvisioned`: This means that an automated system that sets up a TLS certificate was able to do so (e.g., by using LetsEncrypt)
- `IngressReady`: This says that the Ingress, the software responsible for the first bit of traffic management in Knative, is ready to manage the Route. If it is false, then you need to go and investigate whether your Ingress system is up and running

The `Ready` condition is relevant, but by itself, it doesn’t tell you much. That’s because it rolls up the other two conditions. If any of the other conditions are bad (`!!`), then so is `Ready`.

There is more to *Routes* that, by design, kn does not let you directly control, so we have to look at the YAML definition.
```terminal:execute
command: kubectl get route advanced-knative-route-example -o yaml
clear: true
```
`metadata.name` should be familiar, as well as the `apiVersion` and `kind` keys. The core of *Route’s* work lives in `spec.traffic`. And, in fact, traffic is the only key in a *Route’s* spec.
The traffic key is an array of *Traffic Targets*. And it is *Traffic Targets* that are the meat of a *Route*. 

By setting the `latestRevision` to true, you ask *Knative Serving* to update the *Route* to point at the newest *Revision* at any given time. 
When you set `latestRevision` to false, or omit it entirely (which gets counted as false), you will need to provide a `revisionName`. 
You are able to update the `configurationName` and the `revisionName` in the spec, but you have to set one of these at a time and not together in one update.

When you use `kn service create` or submit a *Service* record using kubectl, `latestRevision` defaults to true. This is a sensible default because it requires the least effort from a developer.

### Tags
The kn CLI `--traffic` option enabled you to set routing percentages on particular *Revisions*. Sometimes, though, you don’t want percentages — you want certainties. Suppose you have two *Revisions*, rev-1 and rev-2. If you want to be sure to hit rev-1, you can set its percentage to 100%.

This might not be what you want, however. While it guarantees that your requests all go to rev-1, it also guarantees that everyone’s requests will as well. If your purpose was to debug a flaky function, this is going to cause some problems. What’s needed is to separate two different problems:
- How do you divvy up traffic between *Revisions* using a shared name?
- How can you refer to *Revisions* directly?

Setting a tag is what gives us the ability to directly target a particular *Revision*. Let’s now tag the two latest *Revisions*. 
```terminal:execute
command: kn service update advanced-knative-route-example --tag advanced-knative-route-example-00002=first-tag --tag advanced-knative-route-example-00001=second-tag
clear: true
```
Note that adding a tag doesn’t cause a new *Revision* to be stamped out. That’s because tag is part of a *Route*, not part of a *Configuration*. 
```terminal:execute
command: kn route describe advanced-knative-route-example
clear: true
```
As you can see the main URL is still available. Anything sent to this URL flows according to the configuration of the *Traffic Targets*.
100% of traffic is flowing to @latest becauseyoudidn’t update any -—traffic settings while updating -—tag. The @latest tag is a floating pointer to the latest Revision. This is the same *Revision* that will be pointed to when latestRevision is true.
You can also see that there are now entries for our tagged revisions under the *Traffic Targets*.

In addition to the normal URL, you now have special URLs that only route to particular tags.
Those URLs are of the form http://<tag>-<servicename>.default.example.com.

Now that you have tags, you can use those to split up traffic. This is exactly the same as splitting traffic using a *Revision* name.
```terminal:execute
command: kn service update advanced-knative-route-example --traffic first-tag=50 --traffic second-tag=50
clear: true
```  
```terminal:execute
command: kn route describe advanced-knative-route-example
clear: true
```
What happens if you create another *Revision*? Something you might not have expected: the *Revision* exists but can’t receive traffic. 
```terminal:execute
command: kn service update advanced-knative-route-example --env TARGET=Third
clear: true
``` 
```terminal:execute
command: kn service describe advanced-knative-route-example
clear: true
```
Instead of seeing 0%, you see a `+` symbol.
Right now, this *Revision* isn’t excluded because of how routing arithmetic works when given zeroes—it’s excluded from the routing arithmetic altogether. 
You can figure this out if you have a look at the *Route* instead of the *Service*
```terminal:execute
command: kn route describe advanced-knative-route-example
clear: true
```
That’s why the default *Knative Serving* behavior sets `latestRevision: true` and then updates a floating `@latest` tag automatically.
But when you manually assign traffic percentages, this automatic behavior is disabled and you are given full control. 
Happily, you can undo it pretty easily because `@latest` is always available as a tag. 
```terminal:execute
command: kn service update advanced-knative-route-example --traffic first-tag=33 --traffic second-tag=33 --traffic @latest=34
clear: true
``` 
```terminal:execute
command: kn service describe advanced-knative-route-example
clear: true
```
You are able free up tags via the `--untag` option.
```terminal:execute
command: kn service update advanced-knative-route-example --untag first-tag
clear: true
```
```terminal:execute
command: kn route describe advanced-knative-route-example
clear: true
``` 
Knative Serving opts for safety. This means that as it removes the first-tag tag as the *Traffic Target*, it substitutes the *Revision* that was pointed at by the tag. 

To clean up the environment for the next section run:
```terminal:execute
command: kn service delete advanced-knative-route-example
clear: true
```