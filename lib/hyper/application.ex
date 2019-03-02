defmodule Hyper.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Choose one:
    # Hyper.Handlers.BatchWriteLoop
    # Hyper.Handlers.BatchWriteSend
    # Hyper.Handlers.BatchWriteSpawn
    # Hyper.Handlers.ChunkBatchLoop
    handler = Hyper.Handlers.ChunkBatchSpawn
    # Hyper.Handlers.ChunkSingleSpawn
    # Hyper.Handlers.SingleLoop
    # Hyper.Handlers.SingleSpawn

    children = [
      Hyper.Batch,
      {Hyper.Protocol, {handler, []}}
    ]

    children =
      if Application.get_env(:hyper, :debug) == true do
        [Hyper.Debug | children]
      else
        children
      end

    opts = [strategy: :one_for_one, name: Hyper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
