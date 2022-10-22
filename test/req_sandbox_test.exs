defmodule ReqSandboxTest do
  use ExUnit.Case
  doctest ReqSandbox
  alias Plug.Conn

  setup do
    test_pid = self()

    plug = fn
      %Conn{method: "POST", path_info: path} = conn
      when path in [["sandbox"], ["sandbox-custom"]] ->
        encoded = %{ref: make_ref()} |> :erlang.term_to_binary() |> Base.url_encode64()
        sandbox = "FakeSandbox (#{encoded})"
        send(test_pid, {:sandbox_called, sandbox})

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, sandbox)

      %Conn{method: "DELETE", path_info: path} = conn
      when path in [["sandbox"], ["sandbox-custom"]] ->
        header = Map.get(conn.query_params, "header", "user-agent")
        [sandbox] = Plug.Conn.get_req_header(conn, header)

        send(test_pid, {:sandbox_deleted, sandbox})

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "")

      %Conn{path_info: ["headers", header]} = conn ->
        [value] = Plug.Conn.get_req_header(conn, header)

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, value)

      %Conn{} = conn ->
        raise ArgumentError, "invalid path, got: #{inspect(conn.request_path)}"
    end

    %{req: Req.new(plug: plug)}
  end

  test "requests without a sandbox create a new sandbox", %{req: req} do
    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}
    assert Process.get(:req_sandbox) == encoded

    assert res.body == encoded
  end

  test "requests with existing sandbox re-use the same sandbox", %{req: req} do
    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}
    assert res.body == encoded

    res2 = req |> Req.get!(url: "/headers/user-agent")
    assert res2.body == encoded
    refute_received {:sandbox_called, ^encoded}
  end

  test "delete!/0 deletes the sandbox token from the process dictionary", %{req: req} do
    refute ReqSandbox.delete!()

    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}
    assert res.body == encoded

    assert ReqSandbox.delete!() == encoded

    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded2}
    assert res.body == encoded2

    assert encoded2 != encoded
  end

  test "delete!/1 deletes the sandbox from the server", %{req: req} do
    req = req |> ReqSandbox.attach()

    req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}

    assert ReqSandbox.delete!(req) == encoded

    assert_received {:sandbox_deleted, ^encoded}
  end

  test "requests with a custom sandbox_url", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_url: "/sandbox-custom")
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}
    assert res.body == encoded
  end

  test "requests with a custom sandbox_header", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_header: :x_phoenix_ecto_sandbox)
    res = req |> Req.get!(url: "/headers/x-phoenix-ecto-sandbox")

    assert_received {:sandbox_called, encoded}
    assert res.body == encoded

    ReqSandbox.delete!()

    req = req |> ReqSandbox.attach(sandbox_header: "x-phoenix-ecto-sandbox")
    res = req |> Req.get!(url: "/headers/x-phoenix-ecto-sandbox")

    assert_received {:sandbox_called, encoded}
    assert res.body == encoded
  end

  test "applies sandbox thru tasks", %{req: req} do
    req = req |> ReqSandbox.attach(sandbox_url: "/sandbox-custom")
    res = req |> Req.get!(url: "/headers/user-agent")

    assert_received {:sandbox_called, encoded}
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
end
