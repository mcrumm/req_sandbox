# CHANGELOG

## v0.1.2

- Removes POST body content before making the sandbox request.

- Adds missing `content-length` header on the sandbox request.

- Adds `ReqSandbox.token/0` to fetch the current token if it exists.

## v0.1.1 (2022-12-13)

- Fixes a regression when using Req's `:base_url` option.

## v0.1.0 (2022-10-25)

Initial release
