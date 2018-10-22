"""URL shortcut generator."""

import flask
from flask.views import MethodView

from base_list_view import BaseListView
from models import db, Shortcut

import auth

# Shortcuts may not use these names.
RESERVED_NAMES = {'_create', '_delete', '_edit', '_list', '_ajax'}


class DashboardView(BaseListView):
    template = 'dashboard.html'

    def get_shortcuts(self):
        return (
            Shortcut.query
                .filter(Shortcut.owner == auth.get_current_user())
                .order_by(self.get_order_by())
                .offset(self.offset)
                .limit(self.limit)
                .all()
        )


class ListView(BaseListView):
    template = 'list.html'

    def get_shortcuts(self):
        return (
            Shortcut.query
                .filter()
                .order_by(self.get_order_by())
                .offset(self.offset)
                .limit(self.limit)
                .all()
        )


class CreateShortcutView(MethodView):
    @auth.login_required
    def post(self):
        name = flask.request.form.get('name')
        url = flask.request.form.get('url')
        secondary_url = flask.request.form.get('secondary_url')
        if not name or not url:
            return '"name" and "url" params required', 400
        if name in RESERVED_NAMES:
            return flask.redirect('/?error=%s+is+reserved' % name)
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if shortcut:
            return flask.redirect('/?error=%s+already+exists' % name)

        shortcut = Shortcut(name=name,
                            url=url,
                            secondary_url=secondary_url,
                            owner=auth.get_current_user(),
                            hits=0)
        db.session.add(shortcut)
        db.session.commit()

        return flask.redirect('/?created=%s' % name)


class DeleteShortcutView(MethodView):
    @auth.login_required
    def get(self):
        name = flask.request.args.get('name')
        if name is None:
            return '"name" param is required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect('/?error=%s+does+not+exist' % name)

        template_values = {
            'name': name,
        }
        return flask.render_template('delete.html', **template_values)

    @auth.login_required
    def post(self):
        name = flask.request.form.get('name')
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect('/?error=%s+does+not+exist' % name)

        db.session.delete(shortcut)
        db.session.commit()

        return flask.redirect('/?deleted=%s' % name)


class EditShortcutView(MethodView):
    @auth.login_required
    def get(self):
        name = flask.request.args.get('name')
        if name is None:
            return '"name" param is required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect('/?error=%s+does+not+exist' % name)

        template_values = {
            'name': name,
            'url': shortcut.url,
            'secondary_url': shortcut.secondary_url,
        }
        return flask.render_template('edit.html', **template_values)

    @auth.login_required
    def post(self):
        name = flask.request.form.get('name')
        url = flask.request.form.get('url')
        secondary_url = flask.request.form.get('secondary_url')
        if name is None or url is None:
            return '"name" and "url" params required', 400
        shortcut = Shortcut.query.filter(Shortcut.name == name).first()
        if not shortcut:
            return flask.redirect('/?error=%s+does+not+exist' % name)

        shortcut.url = url
        shortcut.secondary_url = secondary_url
        if auth.get_current_user() != shortcut.owner:
            # Transfer 'ownership'.
            # TODO: Email notification.
            shortcut.owner = auth.get_current_user()

        db.session.add(shortcut)
        db.session.commit()

        return flask.redirect('/?edited=%s' % name)


class ShortcutRedirectView(MethodView):
    @auth.login_required
    def get(self, name):
        secondary_arg = None
        if '/' in name:
            name, secondary_arg = name.split('/', 1)

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
            if secondary_arg and shortcut.secondary_url and '%s' in shortcut.secondary_url:
                response = flask.make_response(
                    flask.redirect(str(shortcut.secondary_url).replace('%s', secondary_arg)))
            else:
                response = flask.make_response(
                    flask.redirect(str(shortcut.url), code=301))
            response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
            return response

        template_values = {
            'name': name,
        }
        return flask.render_template('create.html', **template_values)


class Healthz(MethodView):
    def get(self):
        try:
            db.engine.execute('SELECT 1')
            return 'OK'
        except Exception as e:
            print('Healthz failed: %s' % e)
            return 'Fail', 500
