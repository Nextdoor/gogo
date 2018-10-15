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
`CONFIG` - The configuration to use, like `DevelopmentConfig` or `ProductionConfig`.
`DATABASE_URI` - The full Postgres connection string, like `postgresql://<username>:<password>@<hostname>/<database>` 
`BASE_URL` - The full qualified DNS name that the server will run on, like 'https://gogo.com/'. 
`TITLE` - The title to display in the UI, like 'Nextdoor'. With that, it'd say `Go Nextdoor`.
`BEHIND_PROXY` - If set to `true`, this will add middleware that will respect X-Forwarded-Proto and other proxy headers.

OAuth: One of Built-In Google OAuth or Header-Based Auth must be used.

### If using Built-In Google OAuth:
`GOOGLE_CLIENT_ID` - Your Google App ID.
`GOOGLE_CLIENT_SECRET` - Your Google Client Secret.
`GOOGLE_CLIENT_SECRET_KMS_BLOB` - Alternative to `GOOGLE_CLIENT_SECRET` - KMS Encrypted Google Client Secret.
`AWS_DEFAULT_REGION` - Will be used to determine the AWS region in which to decrypt `*_KMS_BLOB` secrets.
`HOSTED_DOMAIN` - The email domain to use for Google accounts, like 'nextdoor.com'.
`SESSION_SECRET_KEY` - The secret key to encrypt the session cookie with.
`SESSION_SECRET_KEY_KMS_BLOB` - Alternative to `SESSION_SECRET_KEY` - KMS Encrypted Secret Key.

### If using Header-Based Auth:
What is Header-Based auth? Having a proxy in-front of the server which authenticates users somehow (like OAuth) and sends that information to the backend.

**Notes**: 
  * The header should only be included if the request is authenticated.
  * The value of the header should map to a username or email address. This value will be used to differentiate users.

`AUTH_HEADER_NAME` - Name of the header to delegate Auth to.
