defmodule Bonny.EventRecorder do
  @moduledoc """
  Records kubernetes events regarding objects controlled by this operator.
  """

  use Agent

  alias Bonny.Event

  @api_version "events.k8s.io/v1"
  @kind "Event"

  @typedoc """
  A map to identify an event.
  """
  @type event_key :: %{
          action: binary(),
          reason: binary(),
          reporting_controller: binary(),
          regarding: binary(),
          related: binary()
        }

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(opts) do
    Agent.start_link(fn -> %{} end, Keyword.take(opts, [:name]))
  end

  @doc """
  Create a kubernetes event in the cluster.
  Documentation: https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/
  """
  @spec emit(Event.t(), atom(), K8s.Conn.t()) :: :ok
  def emit(event, agent_name, conn) do
    event_time = event.now
    unix_nano = event.now |> DateTime.to_unix(:nanosecond)
    key = event_key(event)

    event_manifest = %{
      "apiVersion" => @api_version,
      "kind" => @kind,
      "metadata" => %{
        "namespace" => Map.get(event.regarding, "namespace", "default"),
        "name" => "#{Map.fetch!(event.regarding, "name")}.#{unix_nano}"
      },
      "eventTime" => event_time,
      "reportingController" => event.reporting_controller,
      "reportingInstance" => event.reporting_instance,
      "action" => event.action,
      "reason" => event.reason,
      "regarding" => event.regarding,
      "related" => event.related,
      "note" => event.message,
      "type" => event.event_type
    }

    event_manifest =
      get_cache(agent_name, key, event_manifest)
      |> increment_series_count()

    apply_op =
      K8s.Client.apply(event_manifest, field_manager: event.reporting_controller, force: true)

    {:ok, _} = K8s.Client.run(conn, apply_op)

    put_cache(agent_name, key, event_manifest)

    :ok
  end

  defp get_cache(agent_name, key, default) do
    Agent.get(agent_name, &Map.get(&1, key, default))
  end

  defp put_cache(agent_name, key, event) do
    event = Map.put_new(event, "series", %{"count" => 1})
    Agent.update(agent_name, &Map.put(&1, key, event))
  end

  defp increment_series_count(event) when is_map_key(event, "series") do
    Map.update!(
      event,
      "series",
      &%{"count" => &1["count"] + 1, "lastObservedTime" => DateTime.utc_now()}
    )
  end

  defp increment_series_count(event), do: event

  @spec event_key(Event.t()) :: event_key()
  defp event_key(event) do
    %{
      action: event.action,
      reason: event.reason,
      reporting_controller: event.reporting_controller,
      regarding: event.regarding,
      related: event.related
    }
  end
end
