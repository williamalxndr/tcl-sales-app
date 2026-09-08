from uuid import uuid4


class RequestIdMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Generate a trusted ID rather than reflecting arbitrary user input.
        request.request_id = "req_" + uuid4().hex
        response = self.get_response(request)
        response["X-Request-Id"] = request.request_id
        if request.path.startswith("/api/"):
            response["Cache-Control"] = "no-store"
        return response
