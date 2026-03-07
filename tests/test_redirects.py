from models import Shortcut, db


class TestShortcutRedirect:
    def test_primary_redirect_301(self, client, make_shortcut):
        make_shortcut(name="go", url="https://example.com")

        resp = client.get("/go")
        assert resp.status_code == 301
        assert resp.headers["Location"] == "https://example.com"

    def test_cache_control_header(self, client, make_shortcut):
        make_shortcut(name="cc", url="https://example.com")

        resp = client.get("/cc")
        assert resp.headers["Cache-Control"] == "no-cache, no-store, must-revalidate"

    def test_secondary_redirect_with_placeholder(self, client, make_shortcut):
        make_shortcut(
            name="jira",
            url="https://jira.com",
            secondary_url="https://jira.com/browse/%s",
        )

        resp = client.get("/jira/PROJ-123")
        assert resp.status_code == 302
        assert resp.headers["Location"] == "https://jira.com/browse/PROJ-123"

    def test_secondary_redirect_multiple_placeholders(self, client, make_shortcut):
        make_shortcut(
            name="multi",
            url="https://example.com",
            secondary_url="https://example.com/%s/page/%s",
        )

        resp = client.get("/multi/foo/bar")
        assert resp.status_code == 302
        assert resp.headers["Location"] == "https://example.com/foo/page/bar"

    def test_secondary_url_without_placeholder_uses_primary(self, client, make_shortcut):
        make_shortcut(
            name="nop",
            url="https://primary.com",
            secondary_url="https://secondary.com/static",
        )

        resp = client.get("/nop/extra")
        assert resp.status_code == 301
        assert resp.headers["Location"] == "https://primary.com"

    def test_hit_counter_increments(self, client, make_shortcut):
        shortcut = make_shortcut(name="hits", url="https://example.com")

        client.get("/hits")
        client.get("/hits")

        updated = db.session.get(Shortcut, shortcut.id)
        assert updated.hits == 2

    def test_missing_shortcut_shows_create_form(self, client):
        resp = client.get("/nonexistent")
        assert resp.status_code == 200
        assert b"nonexistent" in resp.data

    def test_reserved_name_returns_404(self, client):
        resp = client.get("/_ajax")
        assert resp.status_code == 404

    def test_too_many_placeholders_returns_400(self, client, make_shortcut):
        make_shortcut(
            name="bad",
            url="https://example.com",
            secondary_url="https://example.com/%s/%s/%s",
        )

        resp = client.get("/bad/only-one")
        assert resp.status_code == 400
