# Runbook: DevSecOps API Alerts

This runbook provides step-by-step troubleshooting procedures for each alert defined in `k8s/prometheus-rules.yaml`.

---

## DevSecOpsHighErrorRate (Critical)

**Alert**: 5xx error rate > 5% for 2 minutes

### Diagnosis
```bash
# Check current error rate
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'sum(rate(http_requests_total{namespace="staging",status_code=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="staging"}[5m]))'

# Check pod logs for errors
kubectl logs -n staging -l app=devsecops-api --tail=100 | grep -i error

# Check recent deployments
kubectl rollout history deployment/devsecops-api -n staging
```

### Common Causes
1. **Application bug** - New code introduced exception
2. **Dependency failure** - Downstream service unavailable
3. **Resource exhaustion** - OOM kills, CPU throttling
4. **Configuration error** - Wrong environment variables

### Resolution
1. If recent deployment: `kubectl rollout undo deployment/devsecops-api -n staging`
2. Check pod resources: `kubectl top pods -n staging`
3. Scale up if resource pressure: HPA should handle automatically
4. Check upstream dependencies

---

## DevSecOpsHighErrorRate4xx (Warning)

**Alert**: 4xx error rate > 10% for 5 minutes

### Diagnosis
```bash
# Check which endpoints return 4xx
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'sum by (endpoint) (rate(http_requests_total{namespace="staging",status_code=~"4.."}[5m]))'

# Check auth failures specifically
kubectl logs -n staging -l app=devsecops-api | grep "401\|403"
```

### Common Causes
1. **Client integration issues** - Wrong API usage
2. **Token expiration** - JWT tokens expiring
3. **Rate limiting** - If implemented
4. **Breaking API changes**

### Resolution
1. Identify problematic endpoint/client
2. Coordinate with API consumers
3. Check token expiration configuration (30 min default)

---

## DevSecOpsHighLatency (Warning)

**Alert**: P99 latency > 1s for 5 minutes

### Diagnosis
```bash
# Check latency by endpoint
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace="staging"}[5m])) by (le, endpoint))'

# Check resource utilization
kubectl top pods -n staging -l app=devsecops-api

# Check HPA status
kubectl get hpa -n staging
```

### Common Causes
1. **CPU throttling** - Pod hitting CPU limits
2. **Memory pressure** - GC pauses, swapping
3. **Database/query slowness** - If using external DB
4. **Cold starts** - New pods starting up

### Resolution
1. Increase CPU limits/requests in deployment.yaml
2. Check HPA is scaling (should scale at 70% CPU)
3. Consider increasing minReplicas
4. Profile application for bottlenecks

---

## DevSecOpsPodDown (Critical)

**Alert**: Pod not running for 1 minute

### Diagnosis
```bash
# Check pod status
kubectl get pods -n staging -l app=devsecops-api -o wide

# Describe failing pod
kubectl describe pod -n staging <pod-name>

# Check events
kubectl get events -n staging --sort-by=.metadata.creationTimestamp
```

### Common Causes
1. **ImagePullBackOff** - Image not found, auth issues
2. **CrashLoopBackOff** - Application crashing
3. **OOMKilled** - Memory limit exceeded
4. **Node issues** - Node not ready, taints

### Resolution
1. `ImagePullBackOff`: Check GHCR image exists, check imagePullSecrets
2. `CrashLoopBackOff`: Check logs `kubectl logs -n staging <pod-name> --previous`
3. `OOMKilled`: Increase memory limits in deployment.yaml
4. Node issues: Check node status, consider pod disruption budget

---

## DevSecOpsHPAAtMaxReplicas (Warning)

**Alert**: HPA at max replicas (10) for 10 minutes

### Diagnosis
```bash
# Check HPA status
kubectl get hpa -n staging devsecops-api-hpa -o yaml

# Check resource metrics
kubectl top pods -n staging -l app=devsecops-api

# Check current load
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'sum(rate(http_requests_total{namespace="staging"}[5m]))'
```

### Common Causes
1. **Sustained high traffic** - Legitimate load increase
2. **Inefficient code** - High CPU/memory per request
3. **Resource limits too low** - Requests/limits not tuned
4. **HPA metrics misconfigured** - Wrong target utilization

### Resolution
1. If legitimate traffic: Increase `maxReplicas` in hpa.yaml
2. Profile application for optimization
3. Increase resource requests/limits
4. Consider vertical pod autoscaler

---

## DevSecOpsHighMemoryUsage (Warning)

**Alert**: Pod memory > 85% of limit for 5 minutes

### Diagnosis
```bash
# Check memory usage
kubectl top pods -n staging -l app=devsecops-api

# Check memory limits
kubectl get pods -n staging -l app=devsecops-api -o jsonpath='{.items[*].spec.containers[0].resources.limits.memory}'

# Check for memory leaks
kubectl exec -n staging <pod-name> -- python -c "import tracemalloc; tracemalloc.start(); print('tracemalloc available')"
```

### Common Causes
1. **Memory leak** - Objects not being garbage collected
2. **Limits too low** - 512Mi may be insufficient under load
3. **Large request payloads** - Processing large JSON
4. **Dependency caching** - Unbounded caches

### Resolution
1. Increase memory limit in deployment.yaml (e.g., 1Gi)
2. Profile memory usage with `py-spy` or `tracemalloc`
3. Add request size limits in FastAPI
4. Implement cache eviction policies

---

## DevSecOpsHighCPUUsage (Warning)

**Alert**: Pod CPU > 85% of limit for 5 minutes

### Diagnosis
```bash
# Check CPU usage
kubectl top pods -n staging -l app=devsecops-api

# Check CPU limits
kubectl get pods -n staging -l app=devsecops-api -o jsonpath='{.items[*].spec.containers[0].resources.limits.cpu}'

# Profile CPU
kubectl exec -n staging <pod-name> -- py-spy record -o profile.svg --pid 1
```

### Common Causes
1. **CPU limits too low** - 500m may be insufficient
2. **Inefficient algorithms** - O(n²) operations
3. **Excessive logging/serialization** - JSON encoding overhead
4. **Blocking I/O in async code** - Sync calls in async functions

### Resolution
1. Increase CPU limit in deployment.yaml (e.g., 1000m)
2. Profile with `py-spy` or `cProfile`
3. Use `uvicorn --workers >1` for CPU-bound work
4. Optimize hot paths

---

## DevSecOpsRolloutStuck (Warning)

**Alert**: Deployment rollout not completed in 10 minutes

### Diagnosis
```bash
# Check rollout status
kubectl rollout status deployment/devsecops-api -n staging --timeout=30s

# Check replica sets
kubectl get rs -n staging -l app=devsecops-api

# Check pod readiness
kubectl get pods -n staging -l app=devsecops-api
```

### Common Causes
1. **Readiness probe failing** - /ready endpoint not returning 200
2. **Image pull issues** - New image not available
3. **Resource constraints** - Can't schedule new pods
4. **maxUnavailable=0** - Waiting for new pod to be ready before terminating old

### Resolution
1. Check readiness probe: `curl http://<pod-ip>:8000/ready`
2. Verify image exists in GHCR
3. Check node resources: `kubectl describe nodes`
4. Consider increasing `maxSurge` or `maxUnavailable` for faster rollouts

---

## DevSecOpsCertExpiringSoon (Warning)

**Alert**: TLS certificate expires in < 30 days

### Diagnosis
```bash
# Check certificate status
kubectl get certificates -A

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate details
kubectl describe certificate -n staging devsecops-api-tls
```

### Common Causes
1. **cert-manager not renewing** - Controller down, permissions issue
2. **DNS/ACME challenge failing** - Domain not pointing to LB
3. **Rate limited by Let's Encrypt** - Too many renewal attempts

### Resolution
1. Restart cert-manager: `kubectl rollout restart deployment/cert-manager -n cert-manager`
2. Verify DNS points to Ingress LoadBalancer IP
3. Check Let's Encrypt rate limits (50 certs/week per domain)
4. Force renewal: `kubectl delete secret devsecops-api-tls -n staging` (cert-manager will recreate)

---

## General Troubleshooting Commands

```bash
# Full cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Resource usage
kubectl top nodes
kubectl top pods -A

# Recent events
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -50

# Check all deployments
kubectl get deployments -A

# Check HPA across namespaces
kubectl get hpa -A

# Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets

# Alertmanager
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
# Open http://localhost:9093
```

---

## Escalation

If unable to resolve within 15 minutes:
1. Document findings in incident tracker
2. Escalate to team lead / on-call
3. Consider rolling back to previous stable version
4. Communicate status to stakeholders