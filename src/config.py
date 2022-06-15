import os


class Config(object):
    DEBUG = False
    CSRF_ENABLED = True

    TITLE = os.getenv("TITLE", "GoGo")
    BEHIND_PROXY = os.getenv("BEHIND_PROXY", "false").lower() in ["1", "true", "t"]

    SKIP_AUTH = os.getenv("SKIP_AUTH").lower() in ["1", "true", "t"]

    USE_HEADER_AUTH = os.getenv("AUTH_HEADER_NAME") is not None
    AUTH_HEADER_NAME = os.getenv("AUTH_HEADER_NAME")

    USE_GOOGLE_AUTH = os.getenv("AUTH_HEADER_NAME") is None
    HOSTED_DOMAIN = os.getenv("HOSTED_DOMAIN")
    REDIRECT_URI = os.getenv("REDIRECT_URI")


class ProductionConfig(Config):
    DEBUG = False


class DevelopmentConfig(Config):
    DEBUG = True
