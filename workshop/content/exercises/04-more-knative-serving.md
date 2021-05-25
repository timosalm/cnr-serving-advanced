Let's take a closer look at some of the functionalities of Cloud Native Runtimes for Tanzu and the "kn" CLI.

To interact with the service we just deployed, we'll use "kn service update". To get an overview of the operations you can perform, try 
```terminal:execute
command: kn service update --help
```

**Set Scaling Limits.**
You can set the minimum and maximum number of replicas of your application using the "--scale-min" and "--scale-max" parameters. CNR will autoscale the number of replicas of your application between these two limits based on the number of concurrent requests that your application is receiving.

Try setting minimum and maximum scale by running
```terminal:execute
command: kn service update helloworld-go --scale-min 1 --scale-max 5
```

You can disable either scaling limit by setting it to 0. To revert the limits set above, run
```terminal:execute
command: kn service update helloworld-go --scale-min 0 --scale-max 0
```

**Set Resource Requirement Requests.**
You can set resource requests for your application using the "--request" parameter. Try setting a request by doing
```terminal:execute
command: kn service update helloworld-go --request "cpu=50m,memory=128Mi"
```

You can unset requests you've made previously by appending a "-" to the resource name in your request. Try removing the CPU request you just set by doing
```terminal:execute
command: kn service update helloworld-go --request "cpu-"
```

**Change Concurrency Limits.**
You can give Knative a hard limit on the maximum number of concurrent requests that will be sent to a single instance of your application, and you can also set a target number of requests, or percentage utilization, beyond which the runtime will scale up your application. 

To set a hard limit, try
```terminal:execute
command: kn service update helloworld-go --concurrency-limit 50
```
With the above, Knative will never route more than 50 requests at a time to a single instance of your application. 

If you set a hard limit, you should also consider setting a concurrency target (or soft limit) or concurrency utilization percentage. Either one will tell Knative to scale up before the hard limit is hit. By default, if you set a hard limit but do not set either concurrency target or concurrency utilization percentage, then Knative will only scale your application up once the hard limit is hit.

To set a soft limit, try
```terminal:execute
command: kn service update helloworld-go --concurrency-target 25
```
With the above, Knative will scale up if the average number of requests being handled across all instances of your app is greater than 25. Note that the soft limit, unlike the hard limit, can be exceeded. When bursts of requests come in, Knative will continue routing requests to existing instances in excess of the soft limit until new instances come up.

You can also express a soft limit in the form of a utilization percentage. Try
```terminal:execute
command: kn service update helloworld-go --concurrency-utilization 50
```
With the above, Knative will scale up your application if the average number of requests being handled across all instances is greater than 50% of the concurrency limit. In the above case with a concurrency limit of 50 and a concurrency utilization of 50%, scaling up would happen when the average number of requests being handled by all instances of your application exceeds 25.

**Change the Autoscale Window.**
The autoscale window is the duration of the look-back for making autoscaling decisions. The default period is 60 seconds. If no request comes in to your application during this window, it will be scaled down to 0 (or your scale-min). 

Try it out by running
```terminal:execute
command: kn service update helloworld-go --autoscale-window 30s
```
