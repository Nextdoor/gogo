import os

os.environ.setdefault("TITLE", "TestGoGo")
os.environ.setdefault("SKIP_AUTH", "true")
os.environ.setdefault("APP_SETTINGS", "config.DevelopmentConfig")
os.environ.setdefault("DATABASE_URI", "sqlite:///:memory:")

import pytest
from sqlalchemy.pool import StaticPool

from app import app as flask_app
from models import Shortcut, db

# Use StaticPool so all connections share the same in-memory SQLite database.
flask_app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "connect_args": {"check_same_thread": False},
    "poolclass": StaticPool,
}


@pytest.fixture
def app():
    flask_app.config["TESTING"] = True
    with flask_app.app_context():
        db.create_all()
        yield flask_app
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def make_shortcut(app):
    def _make_shortcut(
        name="test",
        url="https://example.com",
        secondary_url=None,
        owner="anonymous",
        hits=0,
    ):
        shortcut = Shortcut(
            name=name,
            url=url,
            secondary_url=secondary_url,
            owner=owner,
            hits=hits,
        )
        db.session.add(shortcut)
        db.session.commit()
        return shortcut

    return _make_shortcut
