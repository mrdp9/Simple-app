# Deployment learning notes

- Learning the app deployment process step by step, starting with the backend/data service and moving toward the frontend.
- The data service is a FastAPI app. Its Dockerfile builds the image, starts Uvicorn on port 8000, and the app has a `/health` endpoint.
- The Pod manifest now references the local image `dataservice:v1` with `imagePullPolicy: Never`; this expects that image to be available to the Kubernetes node.
- Checked the live Pod: it is Pending with `ErrImageNeverPull`. The scheduled node (`k8s-lab-worker2`) does not have `dataservice:v1`, and `Never` means Kubernetes will not pull it. Next learning step: make the built image available to the cluster node, then observe the Pod start.
- Added a liveness probe targeting the app's `/health` route on port `8000`; this now matches the FastAPI app.
- A custom HTTP header is not needed for this app's health endpoint. The probe's short initial delay and interval are okay for practice, though they can cause repeated checks while the app starts.
- HTTP headers are request metadata sent with a request; they are not labels or tags. A probe header only matters if the app or infrastructure is configured to read it (for example, for authentication or routing). The current `Custom-Header: Awesome` value is arbitrary and the data service ignores it.
- Kubernetes can show container logs and open an interactive terminal into a running container; these do not require a special Pod setting. A shell must be present in the image for the terminal.
- **Readiness probe**: use it to decide whether a started container should receive traffic. A failure removes the Pod from Service endpoints without restarting it.
- **Liveness probe**: use it to detect a process that is stuck and should be restarted. Keep it focused on the app itself, not dependencies that might fail temporarily.
- **Startup probe**: use it when initialization can take a while. Kubernetes waits for it to succeed before running liveness or readiness checks; set its failure window long enough for a normal startup.

For this FastAPI service, the matching endpoints are `/ready`, `/health`, and `/startup` on port `8000`:

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8000
  periodSeconds: 5
  failureThreshold: 30 # Allow up to 150 seconds for startup.
readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  periodSeconds: 5
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  periodSeconds: 10
```
