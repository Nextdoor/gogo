# The Nextdoor `go` link service
This is a Web proxy that serves user-defined shortcuts.

You can access "go links" in the browser via `<gogo_host>/<your_link_slug>`.
If a go link exists, it will redirect you to that link.
If a go link does not exist, it will prompt you to create that link.

## Design
Built with Flask, Python 3.6, with Postgres and Google OAuth.

## Endpoints
- The `go/` endpoint will bring you to your personal dashboard. At the top will be the section that you can use to create your own Go links. Below that is a list of all the Go links that you've created before. Below that is a link to all Go links that your organization has created so far, in alphabetical order.
- The `go/_list` endpoint will give you a list of all Go links in your organization. You can add the parameter `?limit={num}` in order to contract or expand that list to a certain number of entries, even into the thousands. You can use `sort=hits` in order to sort on hit count instead of alphabetically. And use `order=desc` in that case, in order to view the links with the most hits first.
- The `go/_create` endpoint will prompt you to create a new Go link, asking you to give the name and URL that you want to shortlink to. If you try to hit `go/{shortname_not_used_yet}`, you will be redirected to the creation page, with the name field already filled in, meaning that you only have to provide the URL.
- The `go/_delete` endpoint requires the `?name={shortname}` arg. This will prompt you to delete the Go link with that name.
- The `go/_edit` endpoint requires the `?name={shortname}` arg as well, and will prompt you to edit the Go link.
- The `go/_ajax/search` endpoint requires either the `name` or `url` arg. If `name` is provided, the search results returned will be the ones that match closest to the name provided, as decided by the Postgres `LIKE` functionality. For the `url` field, all shortnames that map to that URL will be returned. This link is useful for seeing if someone else already created a shortname for the URL that you want to link to, so that you can adopt that shortname instead of introducing another one of your own. This endpoint currently returns the JSON of the search results.

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
`TITLE` - The title to display in the UI, like 'Nextdoor'. With that, it'd say `Go Nextdoor`.
`BEHIND_PROXY` - If set to `true`, this will add middleware that will respect X-Forwarded-Proto and other proxy headers.
`DISABLE_NGINX` - If set to anything, then Nginx will not be started up (useful if you have your own sidecar reverse proxy)

OAuth: One of Built-In Google OAuth or Header-Based Auth must be used.

### If using Built-In Google OAuth:
`BASE_URL` - The full qualified DNS name that the server will run on, like 'https://gogo.com/'. 
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
