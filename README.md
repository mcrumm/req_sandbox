# ReqSandbox

<!-- MDOC -->

[![CI](https://github.com/mcrumm/req_sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/mcrumm/req_sandbox/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex.pm-docs-8e7ce6.svg)](https://hexdocs.pm/req_sandbox)
[![Hex pm](http://img.shields.io/hexpm/v/req_sandbox.svg?style=flat&color=blue)](https://hex.pm/packages/req_sandbox)

[Req][req] plugin for [Phoenix.Ecto.SQL.Sandbox][plug-sandbox].

ReqSandbox simplifies making concurrent, transactional requests to a
Phoenix server. Just before making a request, the sandbox metadata is
applied via the specified request header. If there is no metadata
available, then ReqSandbox creates a new sandbox session and saves
the metadata for future requests. This is mostly useful in client
test environments to ensure logical isolation between concurrent
tests.

## Usage

The [Ecto SQL Sandbox Usage Guide](guides/usage.livemd) contains a full demonstration of the sandbox features.

```elixir
Mix.install([
  {:req, "~> 0.3.0"},
  {:req_sandbox, github: "mcrumm/req_sandbox"}
])

req = Req.new(base_url: "http://localhost:4000" |> ReqSandbox.attach()

Req.post!(req, url: "/api/posts", json: %{"post" => %{"msg" => "Hello, world!"}}).body
# => %{"data" => %{"id" => 2, "msg" => "Hello, world!"}}

ReqSandbox.delete!(req)
# => "BeamMetadata (g2gCZAACdjF0AAAAA2QABW93bmVyWGQAInZ2ZXMzM2o1LWxpdmVib29...)"
```

[req]: https://github.com/wojtekmach/req
[plug-sandbox]: https://github.com/phoenixframework/phoenix_ecto

## License

MIT License. Copyright (c) 2022 Michael A. Crumm Jr.

<!-- MDOC -->
