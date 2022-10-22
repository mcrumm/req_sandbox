defmodule ReqSandbox do
  @moduledoc """
  ReqSandbox simplifies making sandbox requests to a Phoenix server.
  """
  alias Req.{Request, Response}

  @default_sandbox_url "/sandbox"

  @default_sandbox_header :user_agent

  @process_dict_key :req_sandbox

  @doc """
  Attaches to a Req request.

  ## Options

    * `:sandbox_url` - The path to the sandbox. The default value is `"/sandbox"`.

    * `:sandbox_header` - The header to put on the request. The default value is `:user_agent`.

    * `:sandbox_header_token` - If provided, the sandbox header value. Otherwise, an existing
      token from the process will be used. If no token is found, one will be requested from the
      path at `:sandbox_url`. The default value is `nil`.

  """
  def attach(%Request{} = req, options \\ []) do
    req
    |> Request.register_options([:sandbox_url, :sandbox_header, :sandbox_header_token])
    |> Request.merge_options(options)
    |> Request.append_request_steps(run_sandbox: &__MODULE__.run_sandbox/1)
  end

  @doc """
  Deletes the sandbox token from the process dictionary if it exists.
  """
  @spec delete!() :: String.t() | nil
  def delete! do
    Process.delete(@process_dict_key)
  end

  @doc false
  def run_sandbox(%Request{} = req) do
    sandbox =
      if token = Map.get_lazy(req.options, :sandbox_header_token, &find_sandbox/0) do
        token
      else
        create_sandbox!(req)
      end

    header = Map.get(req.options, :sandbox_header, @default_sandbox_header)
    put_sandbox_header(req, header, sandbox)
  end

  defp find_sandbox do
    callers = [self() | Process.get(:"$callers") || []]

    Enum.find_value(callers, fn caller ->
      case Process.info(caller, :dictionary) do
        {:dictionary, dict} -> dict[@process_dict_key]
        nil -> nil
      end
    end)
  end

  defp create_sandbox!(req) do
    url = Map.get(req.options, :sandbox_url, @default_sandbox_url)

    # todo: handle bad responses
    %Response{status: 200, body: sandbox} =
      Req.post!(req, url: url, sandbox_header_token: :ignore)

    Process.put(@process_dict_key, sandbox)
    sandbox
  end

  defp put_sandbox_header(req, _header, :ignore) do
    req
  end

  defp put_sandbox_header(req, header, sandbox) do
    header =
      case header do
        atom when is_atom(header) ->
          atom |> Atom.to_string() |> String.replace("_", "-")

        binary when is_binary(binary) ->
          binary
      end

    Request.put_header(req, header, sandbox)
  end
end
