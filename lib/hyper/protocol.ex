defmodule Hyper.Protocol do
  @type request() ::
          {path :: term(), host :: term(), port :: term(), method :: term(), headers :: term(), qs :: term(), resource :: term()}
  @type handler() :: module()
  @type handler_state() :: term()

  @callback init(term()) :: {:ok, handler_state()}
  @callback handle_requests([request()], state :: handler_state()) :: :ok | {:ok, new_state :: handler_state()} | {:stop, term()}

  def start_link({handler, opts}) when is_atom(handler) do
    :proc_lib.start_link(__MODULE__, :init_it, [self(), handler, opts])
  end

  def child_spec({handler, opts}) when is_atom(handler) do
    %{
      id: handler,
      start: {__MODULE__, :start_link, [{handler, opts}]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker,
      modules: [__MODULE__, handler]
    }
  end

  require Record
  Record.defrecordp(:state, parent: nil, handler: nil, handler_state: nil, read: nil, shutdown: nil)

  require Hyper.Debug.Helpers

  def init_it(parent, handler, opts) do
    case register_name(handler) do
      true ->
        case handler.init(opts) do
          {:ok, handler_state} ->
            init(parent, handler, handler_state)
        end

      {false, pid} ->
        :proc_lib.init_ack(parent, {:error, {:already_started, pid}})
    end
  end

  defp init(parent, handler, handler_state) do
    :ok = :proc_lib.init_ack(parent, {:ok, self()})
    {:ok, shutdown, read} = Hyper.Native.start([])
    state = state(parent: parent, handler: handler, handler_state: handler_state, shutdown: shutdown, read: read)
    before_loop(state)
  end

  defp before_loop(state = state(read: read)) do
    :ok = Hyper.Native.batch_read(read)
    loop(state)
  end

  defp loop(state = state(handler: handler, handler_state: handler_state)) do
    receive do
      {:request, requests} ->
        Hyper.Debug.Helpers.record_rsize!(requests)

        case handler.handle_requests(requests, handler_state) do
          :ok ->
            before_loop(state)

          {:ok, new_handler_state} ->
            new_state = state(state, handler_state: new_handler_state)
            before_loop(new_state)

          {:stop, reason} ->
            _ = system_terminate(reason, state(state, :parent), [], state)
            exit(reason)
        end

      {:system, from, request} ->
        :sys.handle_system_msg(request, from, state(state, :parent), __MODULE__, [], state)

      info ->
        :logger.error('~p received unexpected message ~p~n', [handler, info])
        loop(state)
    end
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

  # System Callbacks

  def system_code_change(misc = state(), _module, _old_vsn, _extra) do
    {:ok, misc}
  end

  def system_continue(parent, _debug, misc = state()) do
    new_misc = state(misc, parent: parent)
    loop(new_misc)
  end

  def system_get_state(misc = state()) do
    {:ok, misc}
  end

  def system_replace_state(state_fun, misc = state()) do
    new_misc = state_fun.(misc)
    {:ok, new_misc, new_misc}
  end

  def system_terminate(_reason, _parent, _debug, _misc = state(shutdown: shutdown)) do
    _ = Hyper.stop(shutdown)
    :ok
  end
end
