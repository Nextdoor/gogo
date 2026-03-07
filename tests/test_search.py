class TestSearch:
    def test_search_by_name(self, client, make_shortcut):
        make_shortcut(name="mylink", url="https://example.com")
        make_shortcut(name="other", url="https://other.com")

        resp = client.get("/_ajax/search?name=mylink")
        data = resp.get_json()
        assert len(data["results"]) == 1
        assert data["results"][0]["name"] == "mylink"

    def test_search_by_url(self, client, make_shortcut):
        make_shortcut(name="a", url="https://example.com/path")
        make_shortcut(name="b", url="https://other.com")

        resp = client.get("/_ajax/search?url=example")
        data = resp.get_json()
        assert len(data["results"]) == 1
        assert data["results"][0]["name"] == "a"

    def test_search_by_name_and_url_uses_or(self, client, make_shortcut):
        make_shortcut(name="alpha", url="https://one.com")
        make_shortcut(name="beta", url="https://alpha.com")

        resp = client.get("/_ajax/search?name=alpha&url=alpha")
        data = resp.get_json()
        assert len(data["results"]) == 2

    def test_search_no_params_returns_400(self, client):
        resp = client.get("/_ajax/search")
        assert resp.status_code == 400

    def test_search_respects_limit(self, client, make_shortcut):
        for i in range(5):
            make_shortcut(name=f"link{i}", url=f"https://example.com/{i}")

        resp = client.get("/_ajax/search?name=link&limit=2")
        data = resp.get_json()
        assert len(data["results"]) == 2

    def test_search_limit_capped_at_max(self, client, make_shortcut):
        make_shortcut(name="solo", url="https://example.com")

        resp = client.get("/_ajax/search?name=solo&limit=999")
        data = resp.get_json()
        assert len(data["results"]) == 1

    def test_search_returns_all_fields(self, client, make_shortcut):
        make_shortcut(
            name="full",
            url="https://example.com",
            secondary_url="https://example.com/%s",
            owner="testuser",
            hits=42,
        )

        resp = client.get("/_ajax/search?name=full")
        result = resp.get_json()["results"][0]
        assert result["name"] == "full"
        assert result["url"] == "https://example.com"
        assert result["secondary_url"] == "https://example.com/%s"
        assert result["owner"] == "testuser"
        assert result["hits"] == 42
