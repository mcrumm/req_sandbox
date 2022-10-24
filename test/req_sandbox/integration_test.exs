defmodule ReqSandbox.IntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  defmodule Repo do
    # req_sandbox doesn't have an otp_app,
    # so we are borrowing one from req
    use Ecto.Repo,
      otp_app: :req,
      adapter: Ecto.Adapters.Postgres
  end

  defmodule Router do
    use Plug.Router

    plug Phoenix.Ecto.SQL.Sandbox, at: "/sandbox", repo: Repo

    plug :match
    plug :dispatch

    get "/headers/:header" do
      [value] = get_req_header(conn, header)

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, value)
    end

    get "/hello" do
      send_resp(conn, 200, "world")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  setup_all do
    pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

    Application.put_env(:req, Repo,
      url: "ecto://#{pg_url}/req_sandbox_test",
      pool: Ecto.Adapters.SQL.Sandbox
    )

    start_supervised!(Repo)

    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

    :ok
  end

  setup do
    %{req: Req.new(plug: Router)}
  end

  test "creates a sandbox, makes a request, and cleans up the sandbox", %{req: req} do
    req = req |> ReqSandbox.attach()
    res = req |> Req.get!(url: "/headers/user-agent")
    encoded = res.body

    assert ReqSandbox.delete!(req) == encoded
  end
end
