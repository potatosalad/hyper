defmodule Hyper.Handlers.BatchWriteSpawn do
  @behaviour Hyper.Protocol

  @impl Hyper.Protocol
  def init(_opts) do
    {:ok, nil}
  end

  @impl Hyper.Protocol
  def handle_requests(requests, _state) do
    body = "Hello world"
    :ok = do_handle_requests(requests, body)
    :ok
  end

  defp do_handle_requests([{_path, _host, _port, _method, _headers, _qs, resource} | requests], body) do
    _ = spawn(:erlang, :send, [Hyper.Batch, [{resource, body}], [:noconnect]])
    do_handle_requests(requests, body)
  end

  defp do_handle_requests([], _body) do
    :ok
  end
end
