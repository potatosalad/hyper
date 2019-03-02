defmodule Hyper.Handlers.BatchWriteSend do
  @behaviour Hyper.Protocol

  @impl Hyper.Protocol
  def init(_opts) do
    {:ok, nil}
  end

  @impl Hyper.Protocol
  def handle_requests(requests, _state) do
    body = "Hello world"
    :ok = do_handle_requests(requests, body, [])
    :ok
  end

  defp do_handle_requests([{_path, _host, _port, _method, _headers, _qs, resource} | requests], body, responses) do
    do_handle_requests(requests, body, [{resource, body} | responses])
  end

  defp do_handle_requests([], _body, responses) do
    _ = :erlang.send(Hyper.Batch, responses, [:noconnect])
    :ok
  end
end
