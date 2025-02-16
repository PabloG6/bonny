defmodule TestResourceV2Controller do
  @moduledoc """
  This controller gets the pid and reference from the resource's spec.
  It then sends a message including that reference, the action and the resource
  name to the pid from the resource.

  A test can therefore create a resource with its own pid (self()), send it
  to kubernetes and wait to receive the message from this controller.
  """

  alias Bonny.API.CRD
  require CRD

  use Bonny.ControllerV2,
    for_resource: CRD.build_for_controller!(versions: [Bonny.Test.API.V1.TestResourceV2])

  rbac_rule({"", ["secrets"], ["get", "watch", "list"]})

  @impl true
  @spec conn() :: K8s.Conn.t()
  def conn(), do: Bonny.Test.IntegrationHelper.conn()

  @impl true
  def add(resource), do: respond(resource, :added)

  @impl true
  def modify(resource), do: respond(resource, :modified)

  @impl true
  def delete(resource), do: respond(resource, :deleted)

  @impl true
  def reconcile(resource), do: respond(resource, :reconciled)

  defp parse_pid(pid), do: pid |> String.to_charlist() |> :erlang.list_to_pid()
  defp parse_ref(ref), do: ref |> String.to_charlist() |> :erlang.list_to_ref()

  defp respond(resource, action) do
    pid = resource |> get_in(["spec", "pid"]) |> parse_pid()
    ref = resource |> get_in(["spec", "ref"]) |> parse_ref()
    name = resource |> get_in(["metadata", "name"])

    send(pid, {ref, action, name})
    :ok
  end
end
