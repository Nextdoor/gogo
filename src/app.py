import os

from flask import Flask, g
from werkzeug.contrib.fixers import ProxyFix
from werkzeug.routing import BaseConverter

import auth
import gogo
import search
from models import db

app = Flask(
    "gogo",
    template_folder="../templates",
    static_url_path="/static",
    static_folder="../static",
)

app.config.from_object(os.environ["APP_SETTINGS"])
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

app.config["SQLALCHEMY_DATABASE_URI"] = os.environ["DATABASE_URI"]

if app.config["BEHIND_PROXY"]:
    app.wsgi_app = ProxyFix(app.wsgi_app)


class RegexConverter(BaseConverter):
    def __init__(self, url_map, *items):
        super(RegexConverter, self).__init__(url_map)
        self.regex = items[0]


app.url_map.converters["regex"] = RegexConverter

if app.config["USE_GOOGLE_AUTH"]:
    # If using Google Auth, the session cookie is the source of truth, so it should be encrypted.
    app.secret_key = os.getenv("SESSION_SECRET_KEY")
    # Register OAuth2 Callback URL for Google Auth.
    app.add_url_rule(
        "/oauth2/callback", view_func=auth.OAuth2Callback.as_view("oauth2_callback")
    )

app.add_url_rule("/healthz", view_func=gogo.Healthz.as_view("healthz"))

app.add_url_rule("/", view_func=gogo.DashboardView.as_view("dashboard"))
app.add_url_rule("/_list", view_func=gogo.ListView.as_view("list"))
app.add_url_rule(
    "/_create", view_func=gogo.CreateShortcutView.as_view("create_shortcut")
)
app.add_url_rule(
    "/_delete", view_func=gogo.DeleteShortcutView.as_view("delete_shortcut")
)
app.add_url_rule("/_edit", view_func=gogo.EditShortcutView.as_view("edit_shortcut"))
app.add_url_rule(
    '/<regex(".+"):name>',
    view_func=gogo.ShortcutRedirectView.as_view("shortcut_redirect"),
)

app.add_url_rule("/_ajax/search", view_func=search.SearchView.as_view("search"))


db.init_app(app)

if __name__ == "__main__":
    db.init_app(app)
    auth.init_app(app)
    app.run()
