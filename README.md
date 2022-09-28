![Bonny](./assets/banner.png "Bonny")

[![Build Status](https://travis-ci.org/coryodaniel/bonny.svg?branch=master)](https://travis-ci.org/coryodaniel/bonny)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/bonny/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/bonny?branch=master)
[![Module Version](https://img.shields.io/hexpm/v/bonny.svg)](https://hex.pm/packages/bonny)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/bonny/)
[![Total Download](https://img.shields.io/hexpm/dt/bonny.svg)](https://hex.pm/packages/bonny)
[![License](https://img.shields.io/hexpm/l/bonny.svg)](https://github.com/coryodaniel/bonny/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/coryodaniel/bonny.svg)](https://github.com/coryodaniel/bonny/commits/master)

# Bonny: Kubernetes Development Framework

Extend the Kubernetes API with Elixir.

Bonny make it easy to create Kubernetes Operators, Controllers, and Custom [Schedulers](./lib/bonny/server/scheduler.ex).

If Kubernetes CRDs and controllers are new to you, read up on the [terminology](#terminology).

## Tutorials and Examples:

_Important!_ These tutorials are for an older version of Bonny, but the `add/1`, `modify/1`, and `delete/1` APIs are the same, as well as a new `reconcile/1` function. Additionally a [k8s](https://github.com/coryodaniel/k8s) has been added!

Feel free to message me on [twitter](https://twitter.com/coryodaniel) if you need any help!

- HelloOperator Tutorial Part: [1](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-1-34ccb2ea0b4d) [2](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-2-efdf8e422085) [3](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-3-fdfc8b8cc843)
- HelloOperator [source code](https://github.com/coryodaniel/hello_operator)

## Talks

- Commandeering Kubernetes @ The Big Elixir 2019
  - [slides](https://speakerdeck.com/coryodaniel/commandeering-kubernetes-with-elixir)
  - [source code](https://github.com/coryodaniel/talks/tree/master/commandeering)
  - [video](https://www.youtube.com/watch?v=0r9YmbH0xTY)

## Example Operators built with Bonny

- [Eviction Operator](https://github.com/bonny-k8s/eviction_operator) - Bonny v 0.4
- [Hello Operator](https://github.com/coryodaniel/hello_operator) - Bonny v 0.4
- [Todo Operator](https://github.com/bonny-k8s/todo-operator) - Bonny v 0.4

## Installation

Bonny can be installed by adding `bonny` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bonny, "~> 0.5"}
  ]
end
```

### Configuration

#### Creating config files

[`mix new <project>` no longer creates initial config files](https://github.com/elixir-lang/elixir/issues/8815).
If you want to follow theses setup instructions you will need to create one.
You can find the full documentation for [`Config` here](https://hexdocs.pm/elixir/1.13.2/Config.html).

#### Configuring Bonny

Bonny uses the [k8s client](https://github.com/coryodaniel/k8s) under the hood.

The only configuration parameters required are `:bonny` `controllers` and a `:get_conn` callback (Note: this file will not exist unless you created it in the previous step):

```elixir

config :bonny,
  # Add each CRD Controller module for this operator to load here
  # Defaults to none. This *must* be set.
  controllers: [
    MyApp.Controllers.WebServer,
    MyApp.Controllers.Database,
    MyApp.Controllers.Memcached
  ],

  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "docker-for-desktop"]]},

  # The API version of the CRD.
  # Defaults to "apiextensions.k8s.io/v1beta1" which is not supported
  # by newer versions of Kubernetes anymore.
  api_version: "apiextensions.k8s.io/v1",

  # The namespace to watch for Namespaced CRDs.
  # Defaults to "default". `:all` for all namespaces
  # Also configurable via environment variable `BONNY_POD_NAMESPACE`
  namespace: "default",

  # Set the Kubernetes API group for this operator.
  # This can be overwritten using the @group attribute of a controller
  group: "your-operator.example.com",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  operator_name: "your-operator",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  service_account_name: "your-operator",

  # Labels to apply to the operator's resources.
  labels: %{
    "kewl": "true"
  },

  # Operator deployment resources. These are the defaults.
  resources: %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }
```

When configuring bonny to run _in your cluster_ the `mix bonny.gen.manifest` command will generate a service account for you. To use that service account configure the `k8s` library like the following:

```elixir
config :bonny,
  get_conn: {K8s.Conn, :from_service_account, []}
```

## Running outside of a cluster

Running an operator outside of Kubernetes is not recommended for production use, but can be very useful when testing.

To start your operator and connect it to an existing cluster, one must first:

1. Have configured your operator. The above example is a good place to start.
2. Have some way of connecting to your cluster. The most common is to connect using your kubeconfig as in the example:

```elixir
# config.exs
config :bonny,
  {K8s.Conn, :from_file, ["~/.kube/config", [context: "optional-alternate-context"]]}
```

3. If RBAC is enabled, you must have permissions for creating and modifying `CustomResourceDefinition`, `ClusterRole`, `ClusterRoleBinding` and `ServiceAccount`.
4. Generate a manifest `mix bonny.gen.manifest` and install it using kubectl `kubectl apply -f manifest.yaml`

Now you are ready to run your operator

```shell
iex -S mix
```

## Bonny Generators

There are a number of generators to help create a Kubernetes operator.

`mix help | grep bonny`

### Generating an operator controller

An operator can have multiple controllers. Each controller handles the lifecycle of a custom resource.

```shell
mix bonny.gen.controller
# or
mix bonny.gen.controller Widget v1
```

Open up your controller and add functionality for your resource's lifecycles:

- Apply (or Add/Modify)
- Delete
- Reconcile; periodically called with each every instance of a CRD's resources

Each controller can create multiple resources.

For example, a _todo app_ controller could deploy a `Deployment` and a `Service`.

Your operator can also have multiple controllers if you want to support multiple resources in your operator!

Check out the [guide](./guides/controllers.livemd):

### Generating a dockerfile

The following command will generate a dockerfile _for your operator_. This will need to be pushed to a docker repository that your Kubernetes cluster can access.

Again, this Dockerfile is for your operator, not for the pods your operator may deploy.

You can skip this step when developing by running your operator _external_ to the cluster.

```shell
mix bonny.gen.dockerfile

export BONNY_IMAGE=YOUR_IMAGE_NAME_HERE
docker build -t ${BONNY_IMAGE} .
docker push ${BONNY_IMAGE}:latest
```

### Generating Kubernetes manifest for operator

This will generate the entire manifest for this operator including:

- CRD manifests
- RBAC
- Service Account
- Operator Deployment

The operator manifest generator requires the `image` flag to be passed if you plan to deploy the operator in your cluster. This is the docker image URL of your operators docker image created by `mix bonny.gen.docker` above.

```shell
mix bonny.gen.manifest --image ${BONNY_IMAGE}
```

You may _omit_ the `--image` flag if you want to generate a manifest _without the deployment_ so that you can develop locally running the operator outside of the cluster.

By default the manifest will generate the service account and deployment in the "default" namespace.

_To set the namespace explicitly:_

```shell
mix bonny.gen.manifest --out - -n test
```

_Alternatively you can apply it directly to kubectl_:

```shell
mix bonny.gen.manifest --out - -n test | kubectl apply -f - -n test
```

## Telemetry

Bonny uses the `telemetry` to emit event metrics.

Events: `Bonny.Sys.Telemetry.events()`

```elixir
[
    [:reconciler, :reconcile, :start],
    [:reconciler, :reconcile, :stop],
    [:reconciler, :reconcile, :exception],
    [:watcher, :watch, :start],
    [:watcher, :watch, :stop],
    [:watcher, :watch, :exception],
    [:scheduler, :binding, :start],
    [:scheduler, :binding, :stop],
    [:scheduler, :binding, :exception],
    [:task, :execution, :start],
    [:task, :execution, :stop],
    [:task, :execution, :exception],
]
```

## Terminology

_[Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources)_:

> A custom resource is an extension of the Kubernetes API that is not necessarily available on every Kubernetes cluster. In other words, it represents a customization of a particular Kubernetes installation.

_[CRD Custom Resource Definition](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions)_:

> The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.

_[Controller](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers)_:

> A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

_[Operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)_:

A set of application specific controllers deployed on Kubernetes and managed via kubectl and the Kubernetes API.

## Testing

Check the guide about testing

## Operator Blog Posts

- [Why Kubernetes Operators are a game changer](https://blog.couchbase.com/kubernetes-operators-game-changer/)
