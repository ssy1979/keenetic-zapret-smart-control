#!/opt/bin/sh
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
f=/opt/kzsc/www/data/telegram-status.json
fallback='{"enabled":false,"configured":false,"has_token":false,"chat_id":"","notify":{"wan":true,"dpi":true,"blockcheck":true,"dns":true,"zapret2":true,"system":true},"last_sent":0,"last_error":""}'
if [ -r "$f" ] && [ -s "$f" ] && grep -Eq '^\{.*\}$' "$f" 2>/dev/null; then
  cat "$f"
else
  printf '%s\n' "$fallback"
fi
