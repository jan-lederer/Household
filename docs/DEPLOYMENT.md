# Dwell deployment verified

Status: **deployed and healthy** on 2026-10-15.

- Host target: `dwell`.
- Job: `ceebef41-736a-442b-889a-4618909a9d93`; terminal status: `succeeded`.
- Running container: `dwell-dwell-1`, Docker health: `healthy`.
- Published address: `0.0.0.0:8081` → container port `8080`.
- Connect the Android app using the same host address as Pocket Codex, changing the port to **8081**.
- HTTP health: `/api/health` returned 200 with `{"status":"ok","service":"dwell"}`.
- Served HTML and JavaScript match the verified release build byte-for-byte.
- Unauthenticated `/api/me` correctly returned 401.

HTTP checks were made through the host's published port from the app container. Phone installation and the phone's network reachability have not been tested.

## Next step

In Dwell, open **Set up server connection**, enter `http://HOST_ADDRESS:8081`, then create your account and household.

## Future deployment

```sh
pocket-docker deploy dwell
pocket-docker job JOB_UUID
pocket-docker status dwell
```

Only a terminal `succeeded` job with passing health checks proves a deployment is complete. Raw evidence is saved in `artifacts/deployment-result.json` and `artifacts/deployment-http.json`.
