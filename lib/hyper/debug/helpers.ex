defmodule Hyper.Debug.Helpers do
  @debug Application.get_env(:hyper, :debug, false) == true

  defmacro record_rsize!(requests) do
    if @debug do
      quote do
        Hyper.Debug.record_rsize(length(unquote(requests)))
      end
    else
      quote(do: nil)
    end
  end

  defmacro record_wsize!(responses) do
    if @debug do
      quote do
        Hyper.Debug.record_wsize(length(unquote(responses)))
      end
    else
      quote(do: nil)
    end
  end

  defmacro maybe_start_batch!(data) do
    if @debug do
      quote do
        case unquote(data) do
          [] ->
            start_time = :erlang.monotonic_time(:microsecond)
            {:reductions, start_reductions} = :erlang.process_info(self(), :reductions)
            _ = :erlang.put(:"$hyper_debug_batch", {start_time, start_reductions})
            :ok

          _ ->
            :ok
        end
      end
    else
      quote(do: nil)
    end
  end

  defmacro record_batch!(data) do
    if @debug do
      quote do
        {:reductions, stop_reductions} = :erlang.process_info(self(), :reductions)
        stop_time = :erlang.monotonic_time(:microsecond)
        {start_time, start_reductions} = :erlang.get(:"$hyper_debug_batch")
        diff = length(unquote(data))
        diff_reductions = abs(div(stop_reductions - start_reductions, diff))
        diff_time = div(stop_time - start_time, diff)
        Hyper.Debug.record_batch(diff_time, diff_reductions)
        :erlang.erase(:"$hyper_debug_batch")
      end
    else
      quote(do: nil)
    end
  end
end
