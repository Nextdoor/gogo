from models import Shortcut, db


class TestCreateShortcut:
    def test_create_success(self, client, make_shortcut):
        resp = client.post(
            "/_create",
            data={"name": "newlink", "url": "https://example.com"},
        )
        assert resp.status_code == 302
        assert "created=newlink" in resp.headers["Location"]

        shortcut = Shortcut.query.filter_by(name="newlink").first()
        assert shortcut is not None
        assert shortcut.url == "https://example.com"
        assert shortcut.owner == "anonymous"
        assert shortcut.hits == 0

    def test_create_with_secondary_url(self, client, make_shortcut):
        resp = client.post(
            "/_create",
            data={
                "name": "jira",
                "url": "https://jira.com",
                "secondary_url": "https://jira.com/browse/%s",
            },
        )
        assert resp.status_code == 302

        shortcut = Shortcut.query.filter_by(name="jira").first()
        assert shortcut.secondary_url == "https://jira.com/browse/%s"

    def test_create_reserved_name_redirects_with_error(self, client):
        resp = client.post(
            "/_create",
            data={"name": "_create", "url": "https://example.com"},
        )
        assert resp.status_code == 302
        assert "error" in resp.headers["Location"]

    def test_create_duplicate_redirects_with_error(self, client, make_shortcut):
        make_shortcut(name="dup", url="https://first.com")

        resp = client.post(
            "/_create",
            data={"name": "dup", "url": "https://second.com"},
        )
        assert resp.status_code == 302
        assert "error" in resp.headers["Location"]

    def test_create_missing_params_returns_400(self, client):
        resp = client.post("/_create", data={})
        assert resp.status_code == 400

    def test_create_missing_url_returns_400(self, client):
        resp = client.post("/_create", data={"name": "nourl"})
        assert resp.status_code == 400


class TestEditShortcut:
    def test_edit_get_form(self, client, make_shortcut):
        make_shortcut(name="editable", url="https://old.com")

        resp = client.get("/_edit?name=editable")
        assert resp.status_code == 200
        assert b"https://old.com" in resp.data

    def test_edit_post_success(self, client, make_shortcut):
        make_shortcut(name="editable", url="https://old.com")

        resp = client.post(
            "/_edit",
            data={"name": "editable", "url": "https://new.com"},
        )
        assert resp.status_code == 302
        assert "edited=editable" in resp.headers["Location"]

        shortcut = Shortcut.query.filter_by(name="editable").first()
        assert shortcut.url == "https://new.com"

    def test_edit_nonexistent_redirects_with_error(self, client):
        resp = client.post(
            "/_edit",
            data={"name": "ghost", "url": "https://example.com"},
        )
        assert resp.status_code == 302
        assert "error" in resp.headers["Location"]

    def test_edit_missing_name_param(self, client):
        resp = client.get("/_edit")
        assert resp.status_code == 400

    def test_edit_post_missing_params(self, client):
        resp = client.post("/_edit", data={})
        assert resp.status_code == 400


class TestDeleteShortcut:
    def test_delete_get_confirmation(self, client, make_shortcut):
        make_shortcut(name="deleteme", url="https://example.com")

        resp = client.get("/_delete?name=deleteme")
        assert resp.status_code == 200
        assert b"deleteme" in resp.data

    def test_delete_post_success(self, client, make_shortcut):
        make_shortcut(name="deleteme", url="https://example.com")

        resp = client.post("/_delete", data={"name": "deleteme"})
        assert resp.status_code == 302
        assert "deleted=deleteme" in resp.headers["Location"]

        assert Shortcut.query.filter_by(name="deleteme").first() is None

    def test_delete_nonexistent_redirects_with_error(self, client):
        resp = client.post("/_delete", data={"name": "ghost"})
        assert resp.status_code == 302
        assert "error" in resp.headers["Location"]

    def test_delete_get_missing_name_returns_400(self, client):
        resp = client.get("/_delete")
        assert resp.status_code == 400
