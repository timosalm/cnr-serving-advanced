Serving encompasses the logic needed to run your software, manage request traffic, keep your software running while you need it, and stop it running when you don’t need it. Knative defines four objects that are used to define and control how a serverless workload behaves on the cluster: *Service*, *Configuration*, *Revision*, and *Route*.

**Configuration** is the statement of what the running system should look like. You provide details about the desired container image, environment variables, and the like. Knative converts this information into lower-level Kubernetes concepts like *Deployments*. In fact, those of you with some Kubernetes familiarity might be wondering what Knative is adding. After all, you can just create and submit a *Deployment* yourself, no need to use another component for that.

Which takes us to **Revisions**. These are snapshots of a *Configuration*. Each time that you change a *Configuration*, Knative first creates a *Revision*, and in fact, it is the *Revision* that is converted into lower-level primitives.
It’s the ability to selectively target traffic that makes *Revisions* a necessity. In vanilla Kubernetes, you can roll forward and can roll back, but you can’t do so with traffic. You can only do it with instances of the Service.

A **Route** maps a network endpoint to one or more *Revisions*. You can manage the traffic in several ways, including fractional traffic and named routes.

A **Service** combines a *Configuration* and a *Route*. This compounding makes common cases easier because everything you will need to know is in one place.

Let's now use kn, the "official" CLI for Knative, exclusively to demonstrate some *Knative Serving* capabilities.

## Your first deployment

We can create a *Service* using kn service create. 
```terminal:execute
command: kn service create intro-knative-example --image gcr.io/knative-samples/helloworld-go --env TARGET="First"          
```

To test our deployment send a request to the application after deployment is ready to serve traffic.
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```

## Your second deployment

```terminal:execute
command: kn service update intro-knative-example --env TARGET="Second"
```
Let’s now send another request to the application after the updated deployment is ready to serve traffic.
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```

If you run the following command you can see that our update command created a second *Revision*. The 1 and 2 suffixes indicate the generation of the *Service*.
```terminal:execute
command: kn revision list
```
Did the second replace the first *Revision*? If you’re an end user sending HTTP requests to the URL, yes, it appears as though a total replacement took place. But from the point of view of a developer, both *Revisions* still exist.

You can look more closely at each of these with `kn revision describe <revision-name>`.
```terminal:execute
command: kn revision describe intro-knative-example-00002
```
It’s worth taking a slightly closer look at the *Conditions*.

## Conditions

Software can be in any number of states, and it can be useful to know what these are.

- **OK** gives the quick summary about whether the news is good or bad. The *++* signals that everything is fine. The *I* signals an informational condition. It’s not bad, but it’s not as unambiguously positive as *++*. If things were going badly, you’d see *!!*. If things are bad but not, like, bad bad, kn signals a warning condition with *W*. And if Knative just doesn’t know what’s happening, you’ll see *??*.
- **TYPE** is the unique condition being described. In this table, we can see four types reported. The *Ready* condition, for example, surfaces the result of an underlying Kubernetes readiness probe. Of greater interest to us is the *Active* condition, which tells us whether there is an instance of the *Revision* running.
- **AGE** reports on when this condition was last observed to have changed. In the example, these are all three hours, but they don’t have to be.
- **REASON** allows a condition to provide a clue as to deeper causes. For example, our *Active* condition shows *NoTraffic* as its reason.

So this line `I Active 11s NoTraffic` can be read as "As of 11 seconds ago, the Active condition has an Informational status due to NoTraffic". It means there are no active instances of the *Revision* running.

If we send another request to the application ...
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```
and rerun the command for the revision details ...
```terminal:execute
command: kn revision describe intro-knative-example-00002
```
we now see `++ Active` without the *NoTraffic* reason. Knative is saying that a running process was created and is active. If you leave it for a minute, the process will shut down again and the *Active* Condition will return to complaining about a lack of traffic.

## Changing the image

Let's now change the container image of the application implemented in Golang to the same application written in Rust ...
```terminal:execute
command: kn service update intro-knative-example --image gcr.io/knative-samples/helloworld-rust
```
and send another request to the updated application deployment.
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```
Changing the environment variable caused the creation of a second *Revision*. Changing the image caused a third *Revision* to be created. But because you didn’t change the variable, the third *Revision* also says `Hello world: Second`. In fact, almost any update you make to a *Service* causes a new *Revision* to be stamped out. Almost any? What’s the exception? It’s *Routes*. Updating these as part of a *Service* won’t create a new *Revision*.

## Splitting traffic
Let's now validate that *Route* updates don’t create new *Revisions* by splitting traffic evenly between the last two *Revisions*. 
```terminal:execute
command: kn service update intro-knative-example --traffic intro-knative-example-00001=50 --traffic intro-knative-example-00002=50
```
The `--traffic` parameter allows us to assign percentages to each *Revision*. The key is that the percentages must all add up to 100. 
As you can see there are still three revisions.
```terminal:execute
command: kn revision list
```

Let's send a request and ...
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```
if you send another request you should see that it works and a slightly different message will be returned from the other *Revision*.
```terminal:execute
command: curl $(kn service describe intro-knative-example -o url)
```
*Hint: If there are timeout issues e.g. due to the scale from zero to one instance, just rerun the command.*


You don’t explicitly need to set traffic to 0% for a *Revision*. You can achieve the same by leaving out *Revisions*.
Finally, you can switch over all the traffic using `@latest` as your target.
```terminal:execute
command: kn service update intro-knative-example --traffic @latest=100
```

To clean up the environment for the next section run:
```terminal:execute
command: kn service delete intro-knative-example
clear: true
```