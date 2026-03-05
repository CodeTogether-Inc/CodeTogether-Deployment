# Dedicated / External Keycloak: startup gate for Intel

This overlay assumes you already have a Keycloak instance running outside of Docker Compose.

If Keycloak is **not** started by Docker Compose (dedicated/external Keycloak), Intel may start too early.
Use the overlay `compose.dedicated-keycloak.yaml` to make Intel wait until Keycloak is reachable.

## Required `.env` entries

Add these to the root `.env` (same directory you pass via `--env-file`):

```dotenv
KEYCLOAK_FQDN=<KEYCLOAK_FQDN>
KEYCLOAK_REALM=<REALM>
```

`KEYCLOAK_REALM` must match the realm used in your OIDC URLs:
`https://<KEYCLOAK_FQDN>/realms/<REALM>/...`

## Run

```bash
docker compose \
  -f compose/compose.yaml \
  -f compose/compose.dedicated-keycloak.yaml \
  --env-file ./.env \
  up --pull always --wait -d
```