- **Reconcilers** act on both user-facing concepts like *Services*, *Revisions*, *Configurations*, and *Routes*, as well as lower-level housekeeping
- **The Webhook** validates and enriches the *Services*, *Configurations*, and *Routes* that users provide
- **Networking controllers** configure TLS certificates and HTTP Ingress routing
- **The Autoscaler/Activator/Queue-Proxy** triad manages the business of comprehending and reacting to changes on traffic

## The controller and reconcilers
*Knative Serving* has a controller process, which is actually a collection of components called "reconcilers." *Reconcilers* act as feedback controllers. They react to changes in the difference between desired and actual worlds.
Each reconciler is responsible for some aspect of *Knative Serving’s* work, which falls into two categories. The first category is simple to understand — it’s the reconcilers responsible for managing the developer-facing resources. Hence, there are reconcilers called configuration, revision, route, and service.

For example, when you use `kn service create`, the first port of call will be for a *Service* record to be picked up by the service controller. When you used kn service update to create a traffic split, you actually get the route controller to do some work for you.

*Reconcilers* in the second category work behind the scenes to carry out essential lower-level tasks. These are *labeler*, *serverlessservice*, and *gc*. The **labeler** is part of how networking works, it essentially sets and maintains labels on Kubernetes objects that networking systems can use to target those for traffic.

The **serverlessservice** (that is the name) reconciler is part of how the *Activator* works. It reacts to and updates serverlessservice records (say that 5 times fast!). These are also mostly about networking in Kubernetes-land.

Lastly, the **gc** reconciler performs garbage-collection duties. Hopefully, you will never need to think about it again.

## The *Webhook*

*Knative Serving* has a webhook process, which intercepts new and updated records you submit. It can then validate your submissions and inject additional information. 
Like the controller, it’s actually a group of logical processes that are collected together into a single physical process for ease of deployment.
The name "Webhook" is a little deceptive because it’s describing the implementation rather than its actual purpose.
It comes from its role as a Kubernetes "admissions webhook". When processing API submissions, the Knative *Webhook* is registered as the delegated authority to inspect and modify *Knative Serving* resources. 

The Webhook’s principal roles include:
- Setting default configurations, including values for timeouts, concurrency limits, container resources limits, and garbage collection timing. This means that you only need to set values you want to override
- Injecting routing and networking information into Kubernetes
- Validating that users didn’t ask for impossible configurations. For example, the Webhook will reject negative concurrency limits
- Resolving partial container image references to include the digest. For example, example/example:latest would be resolved to include the digest, so it looks like example/example@sha256:1a4bccf2....

## Networking controllers

In the default installation provided by the Knative project, Istio is installed as a component and Knative will make use of some of its capabilities.

However, as it has evolved, more of Knative’s networking logic has been abstracted up from Istio. Doing so allows some swappability of components. Istio might make sense for your case, but it’s featuresome and might be overkill. On the other hand, you might have Istio provided as part of your standard Kubernetes environment. Knative extends to either approach.

*Knative Serving* requires that networking controllers answer for two basic record types: Certificate and Ingress.

### Certificates
TLS is essential to the safety and performance of the modern internet, but the business of storing and shipping TLS certificates has always been inconvenient. The Knative certificate abstraction provides information about the TLS certificate that is desired, without providing it directly.

For example, TLS certificates are scoped to particular domain names or IP addresses. When creating a certificate, a list of DNSNames is used to indicate what domains the certificate should be valid for. A conforming controller can then create or obtain certificates that fulfill that need.

### Ingress
Ingress controllers act as a single entrance to the entire Knative installation. These convert Knative’s abstract specification into particular configurations for their own routing infrastructure. For example, the default networking-istio controller will convert a Knative Ingress into an Istio gateway.

## *Autoscaler*, *Activator*, and *Queue-Proxy*
The **Autoscaler** observes demand for a *Service*, calculates the number of instances needed to serve that demand, then updates the *Service’s* scale to reflect the calculation. 
It’s worth noting that the *Knative Pod Autoscaler* operates solely through horizontal scaling. It launches more copies of your software when demand rises.

When there is no traffic, the desired number calculated by the *Autoscaler* is eventually set to zero. This is great, right until a new request shows up without anything ready to serve it. 
In this case, the **Activator** is a traffic target of last resort. Ingress will be configured to send traffic for routes with no active instances to the *Activator*.
The *Activator* remains on the data path during the transition from "no instances" to "enough instances." Once the *Autoscaler* is satisfied that there is enough capacity to meet current demand, it updates the Ingress, changing the traffic target from the *Activator* to the actual running instances. At this point, that *Activator* no longer has any role in the proceedings.

The final component is the **Queue-Proxy**. This is a small proxy process that sits between your actual software and arriving traffic. Every instance of your *Service* will have its own *Queue-Proxy* running as a sidecar. Knative does this for a few reasons. One is to provide a small buffer for requests, allowing the *Activator* to have a clear signal that a request has been accepted for processing (this is called "positive handoff"). Another purpose is to add tracing and metrics to requests flowing in and out of the *Service*.