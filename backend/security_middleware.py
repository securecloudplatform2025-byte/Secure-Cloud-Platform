from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
import time
import hashlib
from collections import defaultdict, deque
from typing import Dict, Deque

class SecurityMiddleware:
    def __init__(self):
        self.request_counts: Dict[str, Deque] = defaultdict(deque)
        self.blocked_ips = set()
        
    def get_client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"
    
    def is_suspicious_request(self, request: Request) -> bool:
        # Check for common attack patterns
        suspicious_patterns = [
            "../", "..\\", "<script", "javascript:", "eval(", "exec(",
            "union select", "drop table", "insert into", "delete from"
        ]
        
        query_string = str(request.url.query).lower()
        path = str(request.url.path).lower()
        
        for pattern in suspicious_patterns:
            if pattern in query_string or pattern in path:
                return True
        
        return False
    
    def check_rate_limit(self, ip: str, limit: int = 100, window: int = 60) -> bool:
        now = time.time()
        
        # Clean old requests
        while self.request_counts[ip] and self.request_counts[ip][0] < now - window:
            self.request_counts[ip].popleft()
        
        # Check if limit exceeded
        if len(self.request_counts[ip]) >= limit:
            self.blocked_ips.add(ip)
            return False
        
        # Add current request
        self.request_counts[ip].append(now)
        return True
    
    async def __call__(self, request: Request, call_next):
        client_ip = self.get_client_ip(request)
        
        # Check if IP is blocked
        if client_ip in self.blocked_ips:
            return JSONResponse(
                status_code=429,
                content={"detail": "IP temporarily blocked due to suspicious activity"}
            )
        
        # Check for suspicious patterns
        if self.is_suspicious_request(request):
            self.blocked_ips.add(client_ip)
            return JSONResponse(
                status_code=400,
                content={"detail": "Suspicious request detected"}
            )
        
        # Rate limiting
        if not self.check_rate_limit(client_ip):
            return JSONResponse(
                status_code=429,
                content={"detail": "Rate limit exceeded"}
            )
        
        response = await call_next(request)
        
        # Add security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        
        return response

security_middleware = SecurityMiddleware()