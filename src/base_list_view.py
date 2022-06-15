import urllib

from flask import current_app, render_template, request
from flask.views import View
from sqlalchemy import asc, desc

import auth

# Keys map to values in list.html for the sortColumn class element val attribute.
SORT_MAP = {
    "hits": "hits",
    "name": "name",
    "owner": "owner",
    "dateCreated": "created_at",
    "url": "url",
    "secondaryUrl": "secondary_url",
}


class BaseListView(View):
    DEFAULT_SORT = "name"
    DEFAULT_ORDER = "asc"
    DEFAULT_LIMIT = 20

    ORDERS = ["asc", "desc"]

    template = None

    def __init__(self):
        self.created = None
        self.edited = None
        self.deleted = None
        self.to = None
        self.error = None
        self.sort = None
        self.order = None
        self.limit = None
        self.offset = None

    def _load_params(self):
        """Load up common URL parameters."""
        # MESSAGING
        self.created = request.args.get("created")
        self.edited = request.args.get("edited")
        self.deleted = request.args.get("deleted")
        self.to = request.args.get("to")
        self.error = request.args.get("error")

        # SORT
        self.sort = SORT_MAP.get(request.args.get("sort"), self.DEFAULT_SORT)
        self.order = request.args.get("order", self.DEFAULT_ORDER)
        if self.order not in self.ORDERS:
            self.order = self.DEFAULT_ORDER

        # LIMIT (page_size for backwards compatibility)
        page_size = int(request.args.get("page_size", self.DEFAULT_LIMIT))
        self.limit = int(request.args.get("limit", page_size)) + 1

        # OFFSET
        self.offset = int(request.args.get("offset", 0))

    def get_previous_offset(self):
        return max(self.offset - self.limit, 0)

    def get_next_offset(self):
        return self.offset + self.limit

    def get_next_url(self):
        params = {
            "offset": self.get_next_offset(),
            "limit": self.limit,
        }
        params.update(self.get_sort_params())
        return urllib.parse.urlencode(params)

    def get_previous_url(self):
        params = {
            "offset": self.get_previous_offset(),
            "limit": self.limit,
        }
        params.update(self.get_sort_params())
        return urllib.parse.urlencode(params)

    def get_shortcuts(self):
        raise NotImplementedError()

    def get_edit_url(self, shortcut):
        return "Edit here: http://go/_edit?%s" % urllib.parse.urlencode(
            {"name": shortcut.name,}
        )

    def get_template_values(self):
        shortcuts = self.get_shortcuts()
        # Remove one from self.limit to undo the earlier offset.
        self.limit -= 1
        has_next = False
        if len(shortcuts) == self.limit + 1:
            # Have an extra shortcut - will be on the next page.
            has_next = True
            # Don't include it on this page.
            shortcuts = shortcuts[:-1]

        return {
            "title": current_app.config["TITLE"],
            "offset": self.offset,
            "previous": self.get_previous_url(),
            "next": self.get_next_url(),
            "shortcuts": shortcuts,
            "has_next": has_next,
            "created": self.created,
            "edited": self.edited,
            "deleted": self.deleted,
            "to": self.to,
            "error": self.error,
        }

    def get_sort_params(self):
        params = {}
        if self.sort != self.DEFAULT_SORT:
            params.update(dict(sort=self.sort))
        if self.order != self.DEFAULT_ORDER:
            params.update(dict(order=self.order))
        return params

    def get_order_by(self):
        if self.order == "asc":
            return asc(self.sort)
        else:
            return desc(self.sort)

    @auth.login_required
    def dispatch_request(self):
        self._load_params()
        return render_template(self.template, **self.get_template_values())
