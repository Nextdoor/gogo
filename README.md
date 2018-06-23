# The Nextdoor `go` link service
This is a Web proxy that serves user-defined shortcuts.

You can access "go links" in the browser via `<gogo_host>/<your_link_slug>`.
If a go link exists, it will redirect you to that link.
If a go link does not exist, it will prompt you to create that link.

## Design
Built with Flask, Python 3.6, with Postgres and Google OAuth.

## Local development
Uses docker.

Run `make postgres` and `make psql-populate` to initialize the database first.

OAuth is required. Secrets can be provided either by direct environment variables or by KMS blobs in environment variables. If using KMS, you'll need to be authenticated to AWS to decrypt the  blobs. `~/.aws` is volume mounted.

When ready, just run `make` to build and run the docker container.

The local service may be accessed at `http://localhost`.

## PyCharm development
I recommend setting the venv built with `make venv` as the remote interpreter.

## Environment Variables
`DATABASE_URI` should be a full postgres connection string, like
 ```
postgresql://<username>:<password>@<hostname>/<database>
```
