import os


class Config(object):
    DEBUG = False
    CSRF_ENABLED = True
    SQLALCHEMY_DATABASE_URI = os.environ['DATABASE_URI']
    REDIRECT_URI = os.environ['REDIRECT_URI']
    HOSTED_DOMAIN = os.environ['HOSTED_DOMAIN']
    TITLE = os.environ['TITLE']


class ProductionConfig(Config):
    DEBUG = False


class DevelopmentConfig(Config):
    DEBUG = True
