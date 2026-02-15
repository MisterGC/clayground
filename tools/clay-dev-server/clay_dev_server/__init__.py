try:
    from importlib.metadata import version
    __version__ = version("clay-dev-server")
except Exception:
    __version__ = "dev"
