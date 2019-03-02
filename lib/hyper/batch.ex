defmodule Hyper.Batch do
  def start_link() do
    :proc_lib.start_link(__MODULE__, :init_it, [self(), __MODULE__])
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :permanent,
      shutdown: 5000,
      type: :worker,
      modules: [__MODULE__]
    }
  end

  require Record
  Record.defrecordp(:state, parent: nil, ready_input: nil, data: [])

  require Hyper.Debug.Helpers

  def init_it(parent, name) do
    case register_name(name) do
      true ->
        init(parent)

      {false, pid} ->
        :proc_lib.init_ack(parent, {:error, {:already_started, pid}})
    end
  end

  def init(parent) do
    :ok = :proc_lib.init_ack(parent, {:ok, self()})
    state = state(parent: parent, ready_input: make_ref())
    loop_notify(state)
  end

  defp loop_notify(state = state(data: data, ready_input: ready_input)) do
    receive do
      message ->
        Hyper.Debug.Helpers.maybe_start_batch!(data)
        send(self(), ready_input)
        loop_passive(state(state, data: add_message(message, data)))
    end
  end

  defp loop_passive(state = state(data: data, ready_input: ready_input)) do
    receive do
      ^ready_input ->
        Hyper.Debug.Helpers.record_batch!(data)
        Hyper.Debug.Helpers.record_wsize!(data)
        :ok = Hyper.Native.batch_send_resp(data)
        loop_notify(state(state, data: []))

      message ->
        Hyper.Debug.Helpers.maybe_start_batch!(data)
        loop_passive(state(state, data: add_message(message, data)))
    end
  end

  defp add_message([message | messages], data) do
    add_message(messages, [message | data])
  end

  defp add_message([], data) do
    data
  end

  defp register_name(name) do
    try do
      :erlang.register(name, self())
    catch
      :error, _ ->
        {false, :erlang.whereis(name)}
    else
      true ->
        true
    end
  end
end
