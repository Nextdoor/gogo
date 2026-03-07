from gogo import _replace_placeholders


class TestReplacePlaceholders:
    def test_single_placeholder(self):
        result = _replace_placeholders("https://jira.com/browse/%s", "PROJ-123")
        assert result == "https://jira.com/browse/PROJ-123"

    def test_multiple_placeholders(self):
        result = _replace_placeholders("https://foo.com/%s/bar/%s", "a/b")
        assert result == "https://foo.com/a/bar/b"

    def test_more_placeholders_than_tokens_returns_none(self):
        result = _replace_placeholders("https://foo.com/%s/%s/%s", "a/b")
        assert result is None

    def test_no_placeholders(self):
        result = _replace_placeholders("https://example.com/path", "ignored")
        assert result == "https://example.com/path"

    def test_extra_tokens_preserved_in_last_placeholder(self):
        result = _replace_placeholders("https://foo.com/%s", "a/b/c")
        assert result == "https://foo.com/a/b/c"

    def test_single_token_single_placeholder(self):
        result = _replace_placeholders("https://go/%s", "test")
        assert result == "https://go/test"

    def test_placeholder_count_equals_token_count(self):
        result = _replace_placeholders("%s/%s", "hello/world")
        assert result == "hello/world"
