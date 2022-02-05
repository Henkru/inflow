FROM mikefarah/yq:4.18.1 AS yq
FROM influxdb:2.0.4-alpine AS inflow

COPY --from=yq /usr/bin/yq /usr/bin/

RUN apk add --update-cache jq

WORKDIR /inflow
COPY src/* .
ENTRYPOINT "/inflow/entry-point.sh"

