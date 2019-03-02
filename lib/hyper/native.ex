defmodule Hyper.Native do
  use Rustler, otp_app: :hyper, crate: :hyperbeam

  def start(_opts), do: error()
  def stop(_resource), do: error()
  def send_resp(_resource, _resp), do: error()
  def batch_read(_resource), do: error()
  def batch_send_resp(_resource_list), do: error()

  defp error, do: :erlang.nif_error(:hyperbeam_not_loaded)
end
