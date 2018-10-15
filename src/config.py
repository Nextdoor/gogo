import os


class Config(object):
    DEBUG = False
    CSRF_ENABLED = True
    SQLALCHEMY_DATABASE_URI = os.environ['DATABASE_URI']
    TITLE = os.environ['TITLE']

    REDIRECT_URI = os.getenv('REDIRECT_URI')
    HOSTED_DOMAIN = os.getenv('HOSTED_DOMAIN')
    AUTH_HEADER_NAME = os.getenv('AUTH_HEADER_NAME')
    USE_HEADER_AUTH = os.getenv('AUTH_HEADER_NAME') is not None
    USE_GOOGLE_AUTH = os.getenv('AUTH_HEADER_NAME') is None
    BEHIND_PROXY = os.getenv('BEHIND_PROXY', '0').lower() in ['1', 'true', 't']


class ProductionConfig(Config):
    DEBUG = False


class DevelopmentConfig(Config):
    DEBUG = True
