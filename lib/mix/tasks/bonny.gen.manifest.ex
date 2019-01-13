defmodule Mix.Tasks.Bonny.Gen.Manifest do
  @moduledoc """
  Generates the Kubernetes YAML manifest for this operator

  mix bonny.gen.manifest expects a docker image name if deploying to a cluster. You may optionally provide a namespace.

  ## Examples

  The `image` switch is required.

  Options:
  * --image (docker image to deploy)
  * --namespace (of service account and deployment; defaults to "default")
  * --out (path to save manifest; defaults to "manifest.yaml")

  *Deploying to kubernetes:*

  ```shell

  docker build -t $(YOUR_IMAGE_URL) .
  docker push $(YOUR_IMAGE_URL)

  mix bonny.gen.manifest --image $(YOUR_IMAGE_URL):latest --namespace default
  kubectl apply -f manifest.yaml -n default
  ```

  To skip the `deployment` for running an operator outside of the cluster (like in development) simply omit the `--image` flag:

  ```shell
  mix bonny.gen.manifest
  ```
  """

  use Mix.Task
  alias Bonny.Operator

  @default_opts [namespace: "default"]
  @switches [out: :string, namespace: :string, image: :string]
  @aliases [o: :out, n: :namespace, i: :image]

  @shortdoc "Generate Kubernetes YAML manifest for this operator"
  def run(args) do
    Mix.Task.run("loadpaths", args)

    {opts, _, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    manifest =
      opts
      |> resource_manifests
      |> Enum.map(fn m -> ["---\n", Jason.encode!(m, pretty: true), "\n"] end)
      |> List.flatten()

    out = opts[:out] || "manifest.yaml"

    Mix.Bonny.render(manifest, out)
  end

  defp resource_manifests(opts) when is_list(opts), do: opts |> Enum.into(%{}) |> resource_manifests
  defp resource_manifests(%{image: image, namespace: namespace}) do
    deployment = Operator.deployment(image, namespace)
    manifests = resource_manifests(%{namespace: namespace})
    [deployment | manifests]
  end

  defp resource_manifests(%{namespace: namespace}) do
    Operator.crds() ++
    [
      Operator.cluster_role(),
      Operator.service_account(namespace),
      Operator.cluster_role_binding(namespace)
    ]
  end
end
