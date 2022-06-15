from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Shortcut(db.Model):
    __tablename__ = "shortcut"

    id = db.Column(db.Integer, primary_key=True, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now(), nullable=False)
    name = db.Column(db.Text, nullable=False, unique=True)
    owner = db.Column(db.Text, nullable=False)
    url = db.Column(db.Text, nullable=False)
    secondary_url = db.Column(db.Text)
    hits = db.Column(db.Integer, nullable=False)

    def __init__(self, name, owner, url, secondary_url, hits):
        self.name = name
        self.owner = owner
        self.url = url
        self.secondary_url = secondary_url
        self.hits = hits

    def __repr__(self):
        return "<id {}>".format(self.id)
