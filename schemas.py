from fastapi import Request
from starlette.responses import RedirectResponse

SESSION_KEY = 'is_admin_logged_in'


def is_logged_in(request: Request) -> bool:
    return bool(request.session.get(SESSION_KEY))


def require_login(request: Request):
    if not is_logged_in(request):
        return RedirectResponse(url='/login', status_code=303)
    return None
