#!/bin/sh
set -o errexit
set -o nounset
set -o xtrace

mkdir -p /etc/docker
cat << EOF > /etc/docker/daemon.json
{
  "labels": {{ INFRAKIT_LABELS | jsonEncode }}
}
EOF

{{/* Reload the engine labels */}}
kill -s HUP $(cat /var/run/docker.pid)
sleep 5

{{ if eq INSTANCE_LOGICAL_ID SPEC.SwarmJoinIP }}

  {{/* The first node of the special allocations will initialize the swarm. */}}
  docker swarm init --advertise-addr {{ INSTANCE_LOGICAL_ID }}

  # Tell Docker to listen on port 4243 for remote API access. This is optional.
  echo DOCKER_OPTS="\"-H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock\"" >> /etc/default/docker
  mkdir -p /etc/systemd/system/docker.service.d/
  echo "[Service]\nExecStart=\nExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock" > /etc/systemd/system/docker.service.d/override.conf 

  # Restart Docker to let port listening take effect.
  systemctl daemon-reload
  service docker restart

{{ else }}

  {{/* The rest of the nodes will join as followers in the manager group. */}}
  docker swarm join --token {{ SWARM_JOIN_TOKENS.Manager }} {{ SPEC.SwarmJoinIP }}:2377

{{ end }}
