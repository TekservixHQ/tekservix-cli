#!/usr/bin/env bash
# Runs both CLIs against a local mock server and checks the requests they make.
set -u
cd "$(dirname "$0")/.." || exit 1
PORT=18765
LOG=$(mktemp)
python3 test/mock_server.py "$PORT" "$LOG" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -f "$LOG"' EXIT
for _ in $(seq 1 50); do curl -s "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.1; done

fails=0
pass() { echo "ok - $1"; }
fail() { echo "not ok - $1"; fails=$((fails + 1)); }
last() { tail -n1 "$LOG"; }
check() { # description, python expression over the last request `r`
  if python3 -c "import json,sys; r=json.loads(sys.argv[1]); sys.exit(0 if ($2) else 1)" "$(last)"; then pass "$1"; else fail "$1: $(last)"; fi
}

export SMSGORA_KEY=sgk_test SMSGORA_BASE_URL="http://127.0.0.1:$PORT/api/"
export WASERVIX_KEY=wpk_test WASERVIX_BASE_URL="http://127.0.0.1:$PORT/api"

bin/smsgora --version | grep -q "smsgora 1.0.0" && pass "smsgora --version" || fail "smsgora --version"
bin/smsgora send --to "+15551234567, +447700900123" --message 'Say "hi"	now' >/dev/null
check "smsgora send body" "r['method']=='POST' and r['path']=='/api/send-sms' and r['key']=='sgk_test' and r['body']=={'recipients':['+15551234567','+447700900123'],'message':'Say \"hi\"\tnow'}"
bin/smsgora send --to +1 --message "Café ✓" --device 42 --sim 1 --schedule 2026-12-01T08:00:00Z >/dev/null
check "smsgora send device/sim/schedule/unicode" "r['path']=='/api/devices/42/send-sms' and r['body']['sim_slot']==1 and r['body']['schedule_at']=='2026-12-01T08:00:00Z' and r['body']['message']=='Café ✓'"
bin/smsgora status 1873 >/dev/null; check "smsgora status" "r['method']=='GET' and r['path']=='/api/messages/1873'"
bin/smsgora cancel 7 >/dev/null; check "smsgora cancel" "r['method']=='POST' and r['path']=='/api/messages/7/cancel'"
bin/smsgora inbox --limit 5 --since 2026-11-01 >/dev/null; check "smsgora inbox query" "r['path']=='/api/received-sms?limit=5&since=2026-11-01'"
bin/smsgora inbox --device 3 >/dev/null; check "smsgora inbox device" "r['path']=='/api/devices/3/get-received-sms'"
bin/smsgora api delete /webhooks/9 >/dev/null; check "smsgora api" "r['method']=='DELETE' and r['path']=='/api/webhooks/9'"
out=$(bin/smsgora account); echo "$out" | grep -q '"ok"' && pass "smsgora prints data" || fail "smsgora prints data: $out"

if SMSGORA_BASE_URL="http://127.0.0.1:$PORT/fail" bin/smsgora account 2>err.txt; then fail "smsgora error exit"; else
  grep -q "Too many requests (HTTP 429)" err.txt && pass "smsgora error message" || fail "smsgora error message: $(cat err.txt)"; fi
bin/smsgora send --to +1 >/dev/null 2>&1; [ $? -eq 2 ] && pass "smsgora usage error" || fail "smsgora usage error"
SMSGORA_KEY="" bin/smsgora account >/dev/null 2>&1; [ $? -eq 2 ] && pass "smsgora needs key" || fail "smsgora needs key"

bin/waservix --version | grep -q "waservix 1.0.0" && pass "waservix --version" || fail "waservix --version"
bin/waservix send --to +1555 --text "hello" >/dev/null
check "waservix send text" "r['path']=='/api/send-message' and r['key']=='Bearer wpk_test' and r['body']=={'to':'+1555','text':'hello'}"
bin/waservix send --to +1 --document https://x/a.pdf --filename a.pdf --caption "Your invoice" >/dev/null
check "waservix send document" "r['body']=={'to':'+1','documentUrl':'https://x/a.pdf','fileName':'a.pdf','text':'Your invoice'}"
bin/waservix send --to 1203@g.us --image https://x/y.jpg >/dev/null
check "waservix send image to group" "r['body']=={'to':'1203@g.us','imageUrl':'https://x/y.jpg'}"
bin/waservix status 58213 >/dev/null; check "waservix status" "r['path']=='/api/messages/58213/info'"
bin/waservix check +1555 >/dev/null; check "waservix check escapes +" "r['path']=='/api/on-whatsapp/%2B1555'"
bin/waservix connection >/dev/null; check "waservix connection" "r['path']=='/api/status'"
if WASERVIX_BASE_URL="http://127.0.0.1:$PORT/soft" bin/waservix send --to +1 --text x 2>err.txt; then fail "waservix success:false"; else
  grep -q "Invalid number" err.txt && pass "waservix success:false is an error" || fail "waservix error message: $(cat err.txt)"; fi
rm -f err.txt

echo "$fails failure(s)"
[ "$fails" -eq 0 ]
