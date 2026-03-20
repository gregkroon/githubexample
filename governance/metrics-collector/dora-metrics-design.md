# DORA Metrics Collection System

## Overview

We must build a custom system to collect and report DORA (DevOps Research & Assessment) metrics:

1. **Deployment Frequency**: How often deployments occur
2. **Lead Time for Changes**: Time from commit to production
3. **Change Failure Rate**: % of deployments causing incidents
4. **Time to Restore Service**: Time to recover from failures

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  GitHub Events                                                │
│  ├── Workflow runs (via webhooks)                            │
│  ├── Deployments                                             │
│  ├── Pull requests                                           │
│  └── Commits                                                 │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ Webhooks
                 ▼
┌──────────────────────────────────────────────────────────────┐
│  DORA Metrics Collector Service (we must build)              │
│  ├── Webhook receiver                                        │
│  ├── Event processor                                         │
│  ├── Metrics calculator                                      │
│  └── API server                                              │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ Store events
                 ▼
┌──────────────────────────────────────────────────────────────┐
│  PostgreSQL Database                                          │
│  ├── deployments table                                       │
│  ├── commits table                                           │
│  ├── incidents table                                         │
│  └── pull_requests table                                     │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ Query metrics
                 ▼
┌──────────────────────────────────────────────────────────────┐
│  Grafana Dashboard                                            │
│  ├── Deployment frequency graph                              │
│  ├── Lead time distribution                                  │
│  ├── Change failure rate                                     │
│  └── MTTR (mean time to recovery)                           │
└──────────────────────────────────────────────────────────────┘
```

## Database Schema

```sql
-- deployments table
CREATE TABLE deployments (
    id UUID PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    environment VARCHAR(50) NOT NULL,
    commit_sha VARCHAR(40) NOT NULL,
    image_digest VARCHAR(255),
    workflow_run_id BIGINT,
    status VARCHAR(50),  -- success, failure, rolled_back
    deployed_at TIMESTAMP NOT NULL,
    deployed_by VARCHAR(255),
    lead_time_seconds INTEGER,  -- calculated from commit to deployment

    -- For tracking rollbacks
    is_rollback BOOLEAN DEFAULT FALSE,
    rollback_of UUID REFERENCES deployments(id),

    CONSTRAINT fk_commit FOREIGN KEY (commit_sha) REFERENCES commits(sha)
);

CREATE INDEX idx_deployments_service_env ON deployments(service_name, environment);
CREATE INDEX idx_deployments_deployed_at ON deployments(deployed_at);

-- commits table
CREATE TABLE commits (
    sha VARCHAR(40) PRIMARY KEY,
    repository VARCHAR(255) NOT NULL,
    author VARCHAR(255),
    committed_at TIMESTAMP NOT NULL,
    message TEXT,
    pull_request_number INTEGER
);

-- pull_requests table
CREATE TABLE pull_requests (
    id SERIAL PRIMARY KEY,
    repository VARCHAR(255) NOT NULL,
    number INTEGER NOT NULL,
    title TEXT,
    created_at TIMESTAMP NOT NULL,
    merged_at TIMESTAMP,
    closed_at TIMESTAMP,
    author VARCHAR(255),
    first_commit_sha VARCHAR(40),
    merge_commit_sha VARCHAR(40),

    UNIQUE(repository, number)
);

-- incidents table (linked to deployments)
CREATE TABLE incidents (
    id UUID PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    environment VARCHAR(50) NOT NULL,
    severity VARCHAR(10),  -- P0, P1, P2
    started_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    caused_by_deployment UUID REFERENCES deployments(id),

    -- For MTTR calculation
    time_to_detect_seconds INTEGER,
    time_to_resolve_seconds INTEGER
);

CREATE INDEX idx_incidents_service ON incidents(service_name, environment);
CREATE INDEX idx_incidents_started_at ON incidents(started_at);
```

## Webhook Integration

### GitHub Webhook Configuration

```yaml
# Webhook URL: https://dora-metrics.example.com/webhooks/github
# Events to subscribe:
events:
  - workflow_run
  - deployment
  - deployment_status
  - push
  - pull_request
```

### Webhook Handler Example

```python
# dora-collector/webhook_handler.py

from flask import Flask, request
import hmac
import hashlib
from datetime import datetime
from database import db

app = Flask(__name__)

@app.route('/webhooks/github', methods=['POST'])
def github_webhook():
    # Verify signature
    signature = request.headers.get('X-Hub-Signature-256')
    if not verify_signature(request.data, signature):
        return 'Invalid signature', 403

    event_type = request.headers.get('X-GitHub-Event')
    payload = request.json

    if event_type == 'workflow_run':
        handle_workflow_run(payload)
    elif event_type == 'deployment_status':
        handle_deployment_status(payload)
    elif event_type == 'push':
        handle_push(payload)
    elif event_type == 'pull_request':
        handle_pull_request(payload)

    return 'OK', 200

def handle_workflow_run(payload):
    """Process workflow run completion"""
    workflow = payload['workflow_run']

    # Only process deployment workflows
    if 'deploy' not in workflow['name'].lower():
        return

    # Extract deployment info from workflow
    # This requires parsing workflow logs or using outputs
    service_name = extract_service_name(workflow)
    environment = extract_environment(workflow)
    commit_sha = workflow['head_sha']

    if workflow['conclusion'] == 'success':
        # Record successful deployment
        db.deployments.insert({
            'service_name': service_name,
            'environment': environment,
            'commit_sha': commit_sha,
            'workflow_run_id': workflow['id'],
            'status': 'success',
            'deployed_at': workflow['updated_at'],
            'deployed_by': workflow['actor']['login'],
        })

        # Calculate lead time
        calculate_lead_time(commit_sha, workflow['updated_at'])

def handle_push(payload):
    """Record commits for lead time calculation"""
    for commit in payload['commits']:
        db.commits.insert({
            'sha': commit['id'],
            'repository': payload['repository']['full_name'],
            'author': commit['author']['username'],
            'committed_at': commit['timestamp'],
            'message': commit['message'],
        })

def calculate_lead_time(commit_sha, deployed_at):
    """Calculate time from commit to deployment"""
    commit = db.commits.find_one({'sha': commit_sha})
    if commit:
        lead_time = (deployed_at - commit['committed_at']).total_seconds()
        db.deployments.update(
            {'commit_sha': commit_sha},
            {'$set': {'lead_time_seconds': lead_time}}
        )
```

## Metrics Calculation

### 1. Deployment Frequency

```sql
-- Deployments per day (last 30 days)
SELECT
    service_name,
    environment,
    DATE(deployed_at) as deployment_date,
    COUNT(*) as deployments
FROM deployments
WHERE deployed_at >= NOW() - INTERVAL '30 days'
    AND status = 'success'
GROUP BY service_name, environment, DATE(deployed_at)
ORDER BY deployment_date DESC;

-- Average deployments per day
SELECT
    service_name,
    environment,
    COUNT(*) / 30.0 as avg_deployments_per_day
FROM deployments
WHERE deployed_at >= NOW() - INTERVAL '30 days'
    AND status = 'success'
GROUP BY service_name, environment;
```

**Elite**: Multiple deployments per day
**High**: Between once per day and once per week
**Medium**: Between once per week and once per month
**Low**: Fewer than once per month

---

### 2. Lead Time for Changes

```sql
-- Average lead time (commit to production deployment)
SELECT
    service_name,
    AVG(lead_time_seconds) / 3600.0 as avg_lead_time_hours,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time_seconds) / 3600.0 as median_lead_time_hours,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lead_time_seconds) / 3600.0 as p95_lead_time_hours
FROM deployments
WHERE deployed_at >= NOW() - INTERVAL '30 days'
    AND environment = 'production'
    AND lead_time_seconds IS NOT NULL
GROUP BY service_name;
```

**Elite**: Less than one hour
**High**: Between one day and one week
**Medium**: Between one week and one month
**Low**: More than one month

---

### 3. Change Failure Rate

```sql
-- Percentage of deployments causing incidents
SELECT
    d.service_name,
    d.environment,
    COUNT(DISTINCT d.id) as total_deployments,
    COUNT(DISTINCT i.id) as failed_deployments,
    (COUNT(DISTINCT i.id)::FLOAT / COUNT(DISTINCT d.id) * 100) as change_failure_rate
FROM deployments d
LEFT JOIN incidents i ON i.caused_by_deployment = d.id
WHERE d.deployed_at >= NOW() - INTERVAL '30 days'
    AND d.environment = 'production'
GROUP BY d.service_name, d.environment;
```

**Challenge**: How do we know which deployment caused an incident?

**Options**:

1. **Manual tagging**: Incident responders tag incidents with deployment ID
2. **Time correlation**: Assume incident was caused by most recent deployment
3. **Automated detection**: Monitor for metric degradation after deployment

```python
def link_incident_to_deployment(incident_started_at, service_name):
    """Find deployment that likely caused incident"""
    # Find most recent deployment before incident
    deployment = db.deployments.find_one({
        'service_name': service_name,
        'environment': 'production',
        'deployed_at': {'$lt': incident_started_at},
    }, sort=[('deployed_at', -1)])

    # Only link if deployment was within 1 hour of incident
    if deployment and (incident_started_at - deployment['deployed_at']).total_seconds() < 3600:
        db.incidents.update(
            {'id': incident_id},
            {'$set': {'caused_by_deployment': deployment['id']}}
        )
```

**Elite**: 0-15%
**High**: 16-30%
**Medium**: 31-45%
**Low**: 46-100%

---

### 4. Time to Restore Service (MTTR)

```sql
-- Mean time to recovery
SELECT
    service_name,
    environment,
    AVG(time_to_resolve_seconds) / 60.0 as avg_mttr_minutes,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY time_to_resolve_seconds) / 60.0 as median_mttr_minutes
FROM incidents
WHERE started_at >= NOW() - INTERVAL '30 days'
    AND resolved_at IS NOT NULL
GROUP BY service_name, environment;
```

**Challenge**: How do we track incidents?

**Options**:

1. **PagerDuty integration**: Sync incidents from PagerDuty
2. **Manual incident logging**: Engineers create incident records
3. **Automated rollback detection**: Track rollback deployments

```python
@app.route('/incidents', methods=['POST'])
def create_incident():
    """API endpoint for creating incidents (called by PagerDuty webhook)"""
    data = request.json

    db.incidents.insert({
        'id': uuid.uuid4(),
        'service_name': data['service_name'],
        'environment': data['environment'],
        'severity': data['severity'],
        'started_at': data['started_at'],
        'resolved_at': None,
    })

    # Try to link to recent deployment
    link_incident_to_deployment(data['started_at'], data['service_name'])

    return 'Created', 201

@app.route('/incidents/<incident_id>/resolve', methods=['POST'])
def resolve_incident(incident_id):
    """Mark incident as resolved"""
    incident = db.incidents.find_one({'id': incident_id})
    resolved_at = datetime.now()

    time_to_resolve = (resolved_at - incident['started_at']).total_seconds()

    db.incidents.update(
        {'id': incident_id},
        {'$set': {
            'resolved_at': resolved_at,
            'time_to_resolve_seconds': time_to_resolve,
        }}
    )

    return 'Resolved', 200
```

**Elite**: Less than one hour
**High**: Less than one day
**Medium**: Between one day and one week
**Low**: More than one week

---

## Grafana Dashboard

```yaml
# grafana/dashboards/dora-metrics.json
{
  "dashboard": {
    "title": "DORA Metrics",
    "panels": [
      {
        "title": "Deployment Frequency",
        "type": "graph",
        "targets": [
          {
            "rawSql": "SELECT deployed_at, COUNT(*) FROM deployments WHERE environment='production' GROUP BY DATE(deployed_at)"
          }
        ]
      },
      {
        "title": "Lead Time Distribution",
        "type": "histogram",
        "targets": [
          {
            "rawSql": "SELECT lead_time_seconds / 3600 as hours FROM deployments WHERE environment='production'"
          }
        ]
      },
      {
        "title": "Change Failure Rate",
        "type": "gauge",
        "targets": [
          {
            "rawSql": "SELECT (COUNT(DISTINCT incidents.id)::FLOAT / COUNT(DISTINCT deployments.id)) * 100 FROM deployments LEFT JOIN incidents ON incidents.caused_by_deployment = deployments.id"
          }
        ]
      },
      {
        "title": "Mean Time to Recovery",
        "type": "stat",
        "targets": [
          {
            "rawSql": "SELECT AVG(time_to_resolve_seconds) / 60 FROM incidents WHERE resolved_at IS NOT NULL"
          }
        ]
      }
    ]
  }
}
```

---

## Integration Points

### From GitHub Actions

Workflows must report deployment events:

```yaml
# In deployment workflow
- name: Report deployment to DORA metrics
  if: success()
  run: |
    curl -X POST https://dora-metrics.example.com/api/deployments \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${{ secrets.DORA_API_TOKEN }}" \
      -d '{
        "service_name": "${{ inputs.service-name }}",
        "environment": "${{ inputs.environment }}",
        "commit_sha": "${{ github.sha }}",
        "image_digest": "${{ needs.ci.outputs.image-digest }}",
        "workflow_run_id": "${{ github.run_id }}",
        "deployed_by": "${{ github.actor }}",
        "deployed_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
      }'
```

**Problem**: This must be added to every deployment workflow across 1000 repos.

**Solution**: Include in reusable workflow (already shown in cd-deploy-direct.yml)

---

## What We Must Build

1. **Webhook receiver service**
   - Flask/FastAPI application
   - Signature verification
   - Event processing
   - Database writes

2. **Database**
   - PostgreSQL
   - Schema migrations
   - Backups
   - Scaling

3. **Metrics API**
   - REST API for querying metrics
   - Aggregation queries
   - Caching for performance

4. **Grafana dashboard**
   - Custom dashboard JSON
   - Data source configuration
   - Alerting rules

5. **Incident management integration**
   - PagerDuty webhook handler
   - Incident-to-deployment linking
   - Resolution tracking

---

## Operational Complexity

**Effort to Build**: 2-4 weeks of development

**Ongoing Maintenance**:
- Database management
- Service uptime (99.9% target)
- Schema migrations
- Performance optimization
- Bug fixes

**Alternatives**:

1. **Sleuth.io**: SaaS DORA metrics ($$)
2. **LinearB**: Engineering metrics platform ($$)
3. **Haystack by Spotify**: Open source (requires setup)
4. **Faros CE**: Open source engineering metrics

**Brutal Truth**: Building accurate DORA metrics is non-trivial. The hardest parts are:
- Linking incidents to deployments
- Calculating lead time across PR → merge → deploy pipeline
- Handling edge cases (rollbacks, hotfixes, manual deployments)
- Maintaining accuracy at scale

Dedicated platforms solve these problems out-of-the-box.
