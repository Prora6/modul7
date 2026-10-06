#!/usr/bin/env bash
# Poll until latest Devnet deploy run completes; print conclusion.
set -uo pipefail
for i in $(seq 1 60); do
  curl -sS -A modul7bot 'https://api.github.com/repos/Prora6/modul7/actions/runs?per_page=3' -o /tmp/runs.json || true
  python3 <<'PY' || true
import json
d=json.load(open('/tmp/runs.json'))
runs=d.get('workflow_runs') or []
if not runs:
    print('no runs / rate limited')
    open('/tmp/latest_status.txt','w').write('unknown')
else:
    r=runs[0]
    print(r['id'], r['status'], r.get('conclusion'), r['head_sha'][:7])
    open('/tmp/latest_status.txt','w').write(r['status'])
    open('/tmp/latest_conclusion.txt','w').write(str(r.get('conclusion')))
    open('/tmp/latest_id.txt','w').write(str(r['id']))
PY
  st=$(cat /tmp/latest_status.txt 2>/dev/null || echo unknown)
  echo "[$i] $st"
  if [ "$st" = "completed" ]; then
    echo conclusion=$(cat /tmp/latest_conclusion.txt)
    id=$(cat /tmp/latest_id.txt)
    curl -sS -A modul7bot "https://api.github.com/repos/Prora6/modul7/actions/runs/$id/jobs" -o /tmp/jobs.json
    python3 <<'PY'
import json
d=json.load(open('/tmp/jobs.json'))
for j in d.get('jobs',[]):
  print(j.get('name'), j.get('conclusion'))
  for s in j.get('steps',[]):
    print(' -', s.get('name'), s.get('conclusion'))
PY
    break
  fi
  sleep 30
done
