"""URL shortcut generator."""
import logging
import os

import flask
from flask.views import MethodView

import auth
from base_list_view import BaseListView
from models import Shortcut, db
from sqlalchemy.sql import  text

# Shortcuts may not use these names.
RESERVED_NAMES = {"_create", "_delete", "_edit", "_list", "_ajax"}
HTTPS_REDIRECT_URL = os.getenv("HTTPS_REDIRECT_URL", "https://localhost")


def _replace_placeholders(input_string, token_string):
    placeholder_count = input_string.count("%s")
    token_count = token_string.count("/") + 1
    if placeholder_count > token_count:
        return None

    tokens = token_string.split("/", placeholder_count-1)
    replaced_string = input_string.replace("%s", "{}").format(*tokens)
    return replaced_string


class DashboardView(BaseListView):
    template = "dashboard.html"

    def get_shortcuts(self):
        return (
            Shortcut.query.filter(Shortcut.owner == auth.get_current_user())
            .order_by(self.get_order_by())
            .offset(self.offset)
            .limit(self.limit)
            .all()
        )


class ListView(BaseListView):
    template = "list.html"

    def get_shortcuts(self):
        return (
            Shortcut.query.filter()
            .order_by(self.get_order_by())
            .offset(self.offset)
            .limit(self.limit)
            .all()
        )


class CreateShortcutView(MethodView):
    @auth.login_required
    def post(self):
        name = flask.request.form.get("name")
        url = flask.request.form.get("url")
        secondary_url = flask.request.form.get("secondary_url")
        if not name or not url:
            return '"name" and "url" params required', 400
        if name in RESERVED_NAMES:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+is+reserved")
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if shortcut:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+already+exists")

        shortcut = Shortcut(
            name=name,
            url=url,
            secondary_url=secondary_url,
            owner=auth.get_current_user(),
            hits=0,
        )
        db.session.add(shortcut)
        db.session.commit()

        return flask.redirect(f"{HTTPS_REDIRECT_URL}/?created={name}")


class DeleteShortcutView(MethodView):
    @auth.login_required
    def get(self):
        name = flask.request.args.get("name")
        if name is None:
            return '"name" param is required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+does+not+exist")

        template_values = {
            "name": name,
        }
        return flask.render_template("delete.html", **template_values)

    @auth.login_required
    def post(self):
        name = flask.request.form.get("name")
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+does+not+exist")

        db.session.delete(shortcut)
        db.session.commit()

        return flask.redirect(f"{HTTPS_REDIRECT_URL}/?deleted={name}")


class EditShortcutView(MethodView):
    @auth.login_required
    def get(self):
        name = flask.request.args.get("name")
        if name is None:
            return '"name" param is required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+does+not+exist")

        template_values = {
            "name": name,
            "url": shortcut.url,
            "secondary_url": shortcut.secondary_url,
        }
        return flask.render_template("edit.html", **template_values)

    @auth.login_required
    def post(self):
        name = flask.request.form.get("name")
        url = flask.request.form.get("url")
        secondary_url = flask.request.form.get("secondary_url")
        if name is None or url is None:
            return '"name" and "url" params required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect(f"{HTTPS_REDIRECT_URL}/?error={name}+does+not+exist")

        shortcut.url = url
        shortcut.secondary_url = secondary_url
        if auth.get_current_user() != shortcut.owner:
            # Transfer 'ownership'.
            # TODO: Email notification.
            shortcut.owner = auth.get_current_user()

        db.session.add(shortcut)
        db.session.commit()

        return flask.redirect(f"{HTTPS_REDIRECT_URL}/?edited={name}")


class ShortcutRedirectView(MethodView):
    @auth.login_required
    def get(self, name):
        secondary_arg = None
        if "/" in name:
            name, secondary_arg = name.split("/", 1)

        if name in RESERVED_NAMES:
            flask.abort(404)

        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if shortcut:
            # TODO: Move the write to a task queue.
            # SUBTODO: Figure out what the above TODO means.
            # TODO: what if more than 1
            shortcut.hits += 1
            db.session.add(shortcut)
            db.session.commit()
            if (
                secondary_arg
                and shortcut.secondary_url
                and "%s" in shortcut.secondary_url
            ):
                formatted_url = _replace_placeholders(str(shortcut.secondary_url), secondary_arg)
                if not formatted_url:
                    flask.abort(400)

                response = flask.make_response(
                    flask.redirect(formatted_url)
                )
            else:
                response = flask.make_response(
                    flask.redirect(str(shortcut.url), code=301)
                )

            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            return response

        template_values = {
            "name": name,
        }
        return flask.render_template("create.html", **template_values)


class Healthz(MethodView):
    def get(self):
        try:
            db.session.execute(text("SELECT 1"))
            return "OK"
        except Exception as e:
            logging.getLogger(__name__).error("Healthz failed: %s", e)
            return "Fail", 500
