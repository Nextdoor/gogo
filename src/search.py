import flask
from flask.views import MethodView
import sqlalchemy

from models import Shortcut

import auth


class SearchView(MethodView):
    DEFAULT_RESULT_LIMIT = 10

    @auth.login_required
    def get(self):
        try:
            name = flask.request.args.get('name')
            url = flask.request.args.get('url')
            result_limit = flask.request.args.get('limit')
            if name is None and url is None:
                raise ValueError('One of params "name", "url" is required.')
            if result_limit is None:
                result_limit = DEFAULT_RESULT_LIMIT
            else:
                result_limit = int(result_limit)

            query = Shortcut.query

            name_like_filter = Shortcut.name.ilike('%{}%'.format(name))
            url_like_filter = Shortcut.url.ilike('%{}%'.format(url))
            if name is not None and url is not None:
                query = query.filter(sqlalchemy.or_(
                    name_like_filter,
                    url_like_filter
                ))
            elif name is not None:
                query = query.filter(name_like_filter)
            elif url is not None:
                query = query.filter(url_like_filter)

            results = query.limit(result_limit).all()
            results = [
                {
                    'name': result.name,
                    'owner': result.owner,
                    'url': result.url,
                    'secondary_url': result.secondary_url,
                    'hits': result.hits,
                }
                for result in results
            ]
            return flask.jsonify(dict(results=results))
        except ValueError as e:
            return flask.jsonify(dict(error=str(e))), 400
        except Exception as e:
            return flask.jsonify(dict(error=str(e))), 500
