defmodule Hyper.Debug do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def record_rsize(n) when is_integer(n) and n >= 0 do
    GenServer.cast(__MODULE__, {:record_rsize, n})
  end

  def record_batch(time, reds) when is_integer(time) and time >= 0 and is_integer(reds) and reds >= 0 do
    GenServer.cast(__MODULE__, {:record_batch, time, reds})
  end

  def record_wsize(n) when is_integer(n) and n >= 0 do
    GenServer.cast(__MODULE__, {:record_wsize, n})
  end

  def show() do
    GenServer.cast(__MODULE__, :show)
  end

  @enforce_keys [:breds, :btime, :rsize, :wsize]
  defstruct [:breds, :btime, :rsize, :wsize]

  @impl GenServer
  def init([]) do
    {:ok, breds} = :hdr_histogram.open(1_000_000, 3)
    {:ok, btime} = :hdr_histogram.open(1_000_000, 3)
    {:ok, rsize} = :hdr_histogram.open(1_000_000, 3)
    {:ok, wsize} = :hdr_histogram.open(1_000_000, 3)
    state = %__MODULE__{breds: breds, btime: btime, rsize: rsize, wsize: wsize}
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:record_rsize, n}, state = %__MODULE__{rsize: rsize}) do
    :ok = :hdr_histogram.record(rsize, n)
    {:noreply, state}
  end

  def handle_cast({:record_batch, time, reds}, state = %__MODULE__{breds: breds, btime: btime}) do
    :ok = :hdr_histogram.record(breds, time)
    :ok = :hdr_histogram.record(btime, reds)
    {:noreply, state}
  end

  def handle_cast({:record_wsize, n}, state = %__MODULE__{wsize: wsize}) do
    :ok = :hdr_histogram.record(wsize, n)
    {:noreply, state}
  end

  def handle_cast(:show, state = %__MODULE__{breds: breds, btime: btime, rsize: rsize, wsize: wsize}) do
    _ = :hdr_histogram.log(breds, :classic, 'breds.hgrm')
    _ = :hdr_histogram.log(btime, :classic, 'btime.hgrm')
    _ = :hdr_histogram.log(rsize, :classic, 'rsize.hgrm')
    _ = :hdr_histogram.log(wsize, :classic, 'wsize.hgrm')

    IO.puts([
      "breds.hgrm\n",
      File.read!("breds.hgrm"),
      "\n",
      "btime.hgrm\n",
      File.read!("btime.hgrm"),
      "\n",
      "rsize.hgrm\n",
      File.read!("rsize.hgrm"),
      "\n",
      "wsize.hgrm\n",
      File.read!("wsize.hgrm")
    ])

    {:noreply, state}
  end
end
