defmodule Bonny.Server.Watcher do
  @moduledoc """
  Creates the stream for watching resources in kubernetes and prepares its processing.

  Watching a resource in kubernetes results in a stream of add/modify/delete events.
  This module uses `K8s.Client.watch_and_stream/3` to create such a stream and maps
  events to a controller's event handler. It is then up to the caller to run the
  resulting stream.

  ## Example

      watch_stream = Bonny.Server.Watcher.get_stream(controller)
      Task.async(fn -> Stream.run(watch_stream) end)
  """

  def get_stream(controller) do
    conn = controller.conn()
    list_operation = controller.list_operation()

    conn
    |> K8s.Client.watch_and_stream(list_operation, [])
    |> Stream.map(&watch_event_handler(controller, &1))
  end

  @spec watch_event_handler(module(), map()) :: any()
  defp watch_event_handler(controller, %{"type" => type, "object" => resource}) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    {measurements, result} =
      case type do
        "ADDED" -> Bonny.Sys.Event.measure(controller, :add, [resource])
        "MODIFIED" -> Bonny.Sys.Event.measure(controller, :modify, [resource])
        "DELETED" -> Bonny.Sys.Event.measure(controller, :delete, [resource])
      end

    case result do
      :ok ->
        Bonny.Sys.Event.watcher_watch_succeeded(measurements, metadata)

      {:ok, _} ->
        Bonny.Sys.Event.watcher_watch_succeeded(measurements, metadata)

      {:error, error} ->
        metadata = Map.put(metadata, :error, error)
        Bonny.Sys.Event.watcher_watch_failed(measurements, metadata)
    end
  end
end
