from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest
import logging
import os

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'notification-service',
        'version': os.getenv('VERSION', '1.0.0')
    })

@app.route('/ready')
def ready():
    return jsonify({'ready': True})

@app.route('/metrics')
def metrics():
    return generate_latest()

@app.route('/api/notifications', methods=['GET'])
@REQUEST_DURATION.labels(method='GET', endpoint='/api/notifications').time()
def get_notifications():
    REQUEST_COUNT.labels(method='GET', endpoint='/api/notifications', status=200).inc()
    notifications = [
        {'id': 1, 'type': 'email', 'status': 'sent', 'user_id': '1'},
        {'id': 2, 'type': 'sms', 'status': 'pending', 'user_id': '2'}
    ]
    return jsonify({'notifications': notifications})

@app.route('/api/notifications/send', methods=['POST'])
@REQUEST_DURATION.labels(method='POST', endpoint='/api/notifications/send').time()
def send_notification():
    data = request.get_json()

    if not data or 'type' not in data or 'user_id' not in data:
        REQUEST_COUNT.labels(method='POST', endpoint='/api/notifications/send', status=400).inc()
        return jsonify({'error': 'Invalid request'}), 400

    logger.info(f"Sending {data['type']} notification to user {data['user_id']}")

    REQUEST_COUNT.labels(method='POST', endpoint='/api/notifications/send', status=201).inc()
    return jsonify({
        'id': 3,
        'type': data['type'],
        'status': 'sent',
        'user_id': data['user_id']
    }), 201

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
