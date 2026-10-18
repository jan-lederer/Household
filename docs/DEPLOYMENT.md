# Dwell deployment verified

Status: **deployed and healthy** on 2026-10-18.

- Host target: `dwell`.
- Job: `581e4d5f-f5d8-498d-98b1-89516dadf8af`; terminal status: `succeeded`.
- Running container: `dwell-dwell-1` (ID `2fa5e3ac0a78`), Docker health: `healthy`.
- Published address: `0.0.0.0:8081` → container port `8080`.
- Connect the Android app using the same host address as Pocket Codex, changing the port to **8081**.
- HTTP health: the host worker check passed for `/api/health` with `{"status":"ok","service":"dwell"}`.
- The host container is running the release built from version 1.1.0+5 (image `sha256:049fd21c2660b1ffa01203786ace9eec18d8c521ef839d82e031ae2fb3627ae1`).

The host worker verified the published service health. Phone installation and the phone's network reachability have not been tested.

## Next step

In Dwell, open **Set up server connection**, enter `http://HOST_ADDRESS:8081`, then create your account and household.

## Future deployment

```sh
pocket-docker deploy dwell
pocket-docker job JOB_UUID
pocket-docker status dwell
```

Only a terminal `succeeded` job with passing health checks proves a deployment is complete. Raw evidence is saved in `artifacts/deployment-result.json` and `artifacts/deployment-http.json`.
