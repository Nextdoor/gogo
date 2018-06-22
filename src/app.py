import os

from flask import g, Flask
from werkzeug.routing import BaseConverter

import auth
import gogo
import search
from models import db

app = Flask('gogo', template_folder='../templates')

app.config.from_object(os.environ['APP_SETTINGS'])
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False


class RegexConverter(BaseConverter):
    def __init__(self, url_map, *items):
        super(RegexConverter, self).__init__(url_map)
        self.regex = items[0]

app.url_map.converters['regex'] = RegexConverter

app.secret_key = os.getenv('SESSION_SECRET_KEY')

app.add_url_rule('/healthz', view_func=gogo.Healthz.as_view('healthz'))
app.add_url_rule('/oauth2/callback', view_func=auth.OAuth2Callback.as_view('oauth2_callback'))

app.add_url_rule('/', view_func=gogo.DashboardView.as_view('dashboard'))
app.add_url_rule('/_list', view_func=gogo.ListView.as_view('list'))
app.add_url_rule('/_create', view_func=gogo.CreateShortcutView.as_view('create_shortcut'))
app.add_url_rule('/_edit', view_func=gogo.EditShortcutView.as_view('edit_shortcut'))
app.add_url_rule('/<regex(".+"):name>', view_func=gogo.ShortcutRedirectView.as_view('shortcut_redirect'))

app.add_url_rule('/_ajax/search', view_func=search.SearchView.as_view('search'))
db.init_app(app)

if __name__ == '__main__':
    db.init_app(app)
    auth.init_app(app)
    app.run()
