defmodule ReqSandboxTest do
  use ExUnit.Case
  doctest ReqSandbox
  alias Plug.Conn

  def plug(%Conn{method: "POST", path_info: path} = conn, test_pid)
      when path in [["sandbox"], ["sandbox-custom"]] do
    encoded = %{ref: make_ref()} |> :erlang.term_to_binary() |> Base.url_encode64()
    sandbox = "FakeSandbox (#{encoded})"

    {:ok, body, _} = Plug.Conn.read_body(conn)

    url =
      "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"
      |> URI.parse()
      |> URI.to_string()

    send(test_pid, {:sandbox_called, %{url: url, sandbox: sandbox, body: body}})

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, sandbox)
  end

  def plug(%Conn{method: "DELETE", path_info: path} = conn, test_pid)
      when path in [["sandbox"], ["sandbox-custom"]] do
    header = Map.get(conn.query_params, "header", "user-agent")
    [sandbox] = Plug.Conn.get_req_header(conn, header)

    send(test_pid, {:sandbox_deleted, sandbox})

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "")
  end

  def plug(%Conn{path_info: ["headers", header]} = conn, _test_pid) do
    [value] = Plug.Conn.get_req_header(conn, header)

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, value)
  end

  def plug(%Conn{} = conn, _test_pid) do
    raise ArgumentError, "invalid path, got: #{inspect(conn.request_path)}"
  end

  setup do
    test_pid = self()

    %{req: Req.new(plug: &plug(&1, test_pid))}
  end

  test "requests without a sandbox create a new sandbox", %{req: req} do
    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert Process.get(:req_sandbox) == encoded

    assert res.body == encoded
  end

  test "requests with existing sandbox re-use the same sandbox", %{req: req} do
    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded

    res2 = req |> Req.get!(url: "/headers/user-agent")
    assert res2.body == encoded
    refute_received {:sandbox_called, %{sandbox: ^encoded}}
  end

  test "delete!/0 deletes the sandbox token from the process dictionary", %{req: req} do
    refute ReqSandbox.delete!()

    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded

    assert ReqSandbox.delete!() == encoded

    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded2}}
    assert res.body == encoded2

    assert encoded2 != encoded
  end

  test "delete!/1 deletes the sandbox from the server", %{req: req} do
    req = req |> ReqSandbox.attach()

    req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}

    assert ReqSandbox.delete!(req) == encoded

    assert_received {:sandbox_deleted, ^encoded}
  end

  test "requests with a custom sandbox_url", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_url: "/sandbox-custom")
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded
  end

  test "requests with a custom sandbox_header", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_header: :x_phoenix_ecto_sandbox)
    res = req |> Req.get!(url: "/headers/x-phoenix-ecto-sandbox")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded

    ReqSandbox.delete!()

    req = req |> ReqSandbox.attach(sandbox_header: "x-phoenix-ecto-sandbox")
    res = req |> Req.get!(url: "/headers/x-phoenix-ecto-sandbox")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded
  end

  test "applies sandbox thru tasks", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_url: "/sandbox-custom")
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{sandbox: encoded}}
    assert res.body == encoded

    res2 =
      Task.async(fn ->
        Task.async(fn ->
          req |> Req.get!(url: "/headers/user-agent")
        end)
        |> Task.await()
      end)
      |> Task.await()

    assert res2.body == encoded
  end

  test "with base_url" do
    Req.new(base_url: "http://custom", plug: &plug(&1, self()))
    |> ReqSandbox.attach()
    |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{url: "http://custom/sandbox"}}

    ReqSandbox.delete!()

    Req.new(base_url: "http://new/headers/user-agent", plug: &plug(&1, self()))
    |> ReqSandbox.attach()
    |> Req.get!(url: "http://get/headers/user-agent")

    assert_received {:sandbox_called, %{url: "http://get/sandbox"}}
  end

  test "base_url does not override absolute sandbox url" do
    Req.new(base_url: "http://custom", plug: &plug(&1, self()))
    |> ReqSandbox.attach(sandbox_url: "http://sandbox/sandbox")
    |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, %{url: "http://sandbox/sandbox"}}
  end

  test "token/0 returns the current sandbox token or nil if none exists", %{req: req} do
    req = req |> ReqSandbox.attach()

    assert ReqSandbox.token() == nil

    req |> Req.get!(url: "/headers/user-agent")

    token = ReqSandbox.token()
    assert token

    awaited =
      Task.async(fn ->
        Task.async(fn ->
          ReqSandbox.token()
        end)
        |> Task.await()
      end)
      |> Task.await()

    assert awaited == token
  end

  test "sandbox request body is empty", %{req: req} do
    req = req |> ReqSandbox.attach()

    req |> Req.get!(url: "/headers/user-agent")
    assert_received {:sandbox_called, %{body: ""}}

    ReqSandbox.delete!()
    req |> Req.post!(url: "/headers/user-agent", body: "custom")
    assert_received {:sandbox_called, %{body: ""}}

    ReqSandbox.delete!()
    req |> Req.post!(url: "/headers/user-agent", json: %{:a => :b})
    assert_received {:sandbox_called, %{body: ""}}

    ReqSandbox.delete!()
    req |> Req.post!(url: "/headers/user-agent", form: %{:c => :d})
    assert_received {:sandbox_called, %{body: ""}}
  end
end
