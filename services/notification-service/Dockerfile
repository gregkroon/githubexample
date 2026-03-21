# CRITICAL: This base image must be from approved list
# In production: Validated by OPA policy in CI pipeline
FROM python:3.11-alpine

# Non-root user (security requirement)
RUN addgroup -g 1001 -S appuser && adduser -S appuser -u 1001 -G appuser

WORKDIR /app

# Copy requirements file
COPY requirements.txt ./

# Install production dependencies only
RUN pip install --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache

# Copy application code
COPY --chown=appuser:appuser app.py ./

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1

# Start application
CMD ["python", "app.py"]
