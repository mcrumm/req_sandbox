defmodule ReqSandbox do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

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

  @doc """
  Deletes the sandbox from the server and the process dictionary, if it exists.
  """
  @spec delete!(Request.t()) :: String.t() | nil
  def delete!(%Request{} = req) do
    url = Map.get(req.options, :sandbox_url, @default_sandbox_url)
    %Response{status: 200} = Req.delete!(req, url: url)
    delete!()
  end

  @doc """
  Returns the current sandbox token or `nil` if no sandbox exists.

  ## Examples

      ReqSandbox.token()
      #=> "BeamMetadata (g2gCZAACdjF0AAAAA2QABW93bmVyWGQAInZ2ZXMzM2o1LWxpdmVib29...)"
  """
  @spec token :: nil | String.t()
  def token do
    callers = [self() | Process.get(:"$callers") || []]

    Enum.find_value(callers, fn caller ->
      case Process.info(caller, :dictionary) do
        {:dictionary, dict} -> dict[@process_dict_key]
        nil -> nil
      end
    end)
  end

  @doc false
  def run_sandbox(%Request{} = req) do
    sandbox =
      if token = Map.get_lazy(req.options, :sandbox_header_token, &token/0) do
        token
      else
        create_sandbox!(req)
      end

    header = Map.get(req.options, :sandbox_header, @default_sandbox_header)
    put_sandbox_header(req, header, sandbox)
  end

  defp create_sandbox!(req) do
    # todo: handle bad responses
    %Response{status: 200, body: sandbox} =
      req
      |> put_sandbox_url()
      |> Req.post!(sandbox_header_token: :ignore)

    Process.put(@process_dict_key, sandbox)
    sandbox
  end

  defp put_sandbox_url(req) do
    sandbox_url = req.options |> Map.get(:sandbox_url, @default_sandbox_url) |> URI.parse()

    # Apply the base URL (if present) to ensure we can merge from an absolute URL
    req |> Req.Steps.put_base_url() |> put_sandbox_url(sandbox_url)
  end

  defp put_sandbox_url(req, sandbox_url) do
    update_in(req.url, fn url ->
      if url.scheme do
        url |> URI.merge(sandbox_url)
      else
        sandbox_url
      end
    end)
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
