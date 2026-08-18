#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh
CGI="$KZSC_HOME/www/cgi-bin"
mkdir -p "$CGI"

# Generated CGI scripts run under lighttpd and must not depend on the SSH PATH.
CGI_PATH='/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin'

cat > "$CGI/dns_diag.cgi" <<'EOF'
#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
nd="$(command -v ndmc 2>/dev/null || true)"
[ -n "$nd" ] || { for x in /opt/bin/ndmc /bin/ndmc /usr/bin/ndmc /sbin/ndmc /usr/sbin/ndmc; do [ -x "$x" ] && { nd="$x"; break; }; done; }
esc(){ printf '%s' "$1" | tr '\r\n' '  ' | sed 's/\\/\\\\/g;s/"/\\"/g;s/	/ /g'; }
if [ -n "$nd" ]; then
  out="$(LD_LIBRARY_PATH= "$nd" -c 'show version' 2>&1)"; rc=$?
  printf '{"ok":%s,"path":"%s","rc":%s,"message":"%s"}\n' "$( [ "$rc" -eq 0 ] && echo true || echo false )" "$(esc "$nd")" "$rc" "$(esc "$out")"
else
  printf '{"ok":false,"path":"","rc":127,"message":"ndmc bulunamadı"}\n'
fi
EOF
chmod 755 "$CGI/dns_diag.cgi"

cat > "$CGI/dns_status.cgi" <<'EOF'
#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
esc(){ printf '%s' "\$1" | tr '\\r\\n' '  ' | sed 's/\\\\/\\\\\\\\/g;s/"/\\\"/g;s/\t/ /g'; }
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
out="$(/opt/kzsc/bin/kzsc-dns.sh status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ] && printf '%s' "$out" | grep -q '^{'; then
  printf '%s\n' "$out"
else
  err="$(printf '%s' "${out:-DNS status backend boş yanıt döndürdü.}" | tr '\r\n' '  ' | sed 's/\\/\\\\/g;s/"/\\"/g')"
  printf '{"ok":false,"enabled":false,"provider":"cloudflare","provider_name":"Cloudflare","protocol":"both","ignore_isp":false,"clean_install":false,"last_backup":"","updated":0,"wans":[],"error":"%s"}\n' "$err"
fi
EOF
chmod 755 "$CGI/dns_status.cgi"

cat > "$CGI/dns_disable.cgi" <<'EOF'
#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
esc(){ printf '%s' "\$1" | tr '\\r\\n' '  ' | sed 's/\\\\/\\\\\\\\/g;s/"/\\\"/g;s/\t/ /g'; }
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
out="$(/opt/kzsc/bin/kzsc-dns.sh disable 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf '{"ok":true,"message":"%s"}\n' "$(printf '%s' "$out"|sed 's/\\/\\\\/g;s/"/\\"/g')"
else
  printf '{"ok":false,"error":"%s"}\n' "$(printf '%s' "$out"|sed 's/\\/\\\\/g;s/"/\\"/g')"
fi
EOF
chmod 755 "$CGI/dns_disable.cgi"

for provider in cloudflare google quad9 adguard; do
  for protocol in dot doh both; do
    for ignore in 0 1; do
      suffix=keep; [ "$ignore" = "1" ] && suffix=ignore
      f="$CGI/dns_apply_${provider}_${protocol}_${suffix}.cgi"
      cat > "$f" <<EOF
#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
esc(){ printf '%s' "\$1" | tr '\\r\\n' '  ' | sed 's/\\\\/\\\\\\\\/g;s/"/\\\"/g;s/\t/ /g'; }
printf 'Content-Type: application/json\\r\\nCache-Control: no-store\\r\\n\\r\\n'
out="\$(/opt/kzsc/bin/kzsc-dns.sh apply '$provider' '$protocol' '$ignore' 2>&1)"; rc=\$?
if [ "\$rc" -eq 0 ]; then
  printf '{"ok":true,"message":"%s"}\\n' "\$(printf '%s' "\$out"|sed 's/\\\\/\\\\\\\\/g;s/"/\\\\"/g')"
else
  printf '{"ok":false,"error":"%s"}\\n' "\$(printf '%s' "\$out"|sed 's/\\\\/\\\\\\\\/g;s/"/\\\\"/g')"
fi
EOF
      chmod 755 "$f"
    done
  done
done


for provider in cloudflare google quad9 adguard; do
  for protocol in dot doh both; do
    for ignore in 0 1; do
      suffix=keep; [ "$ignore" = "1" ] && suffix=ignore
      f="$CGI/dns_clean_${provider}_${protocol}_${suffix}.cgi"
      cat > "$f" <<EOF
#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
esc(){ printf '%s' "\$1" | tr '\\r\\n' '  ' | sed 's/\\\\/\\\\\\\\/g;s/"/\\\"/g;s/\t/ /g'; }
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
out="\$(/opt/kzsc/bin/kzsc-dns.sh clean-apply '$provider' '$protocol' '$ignore' 2>&1)"; rc=\$?
if [ "\$rc" -eq 0 ]; then
  printf '{"ok":true,"message":"%s"}\n' "\$(esc "\$out")"
else
  printf '{"ok":false,"error":"%s"}\n' "\$(esc "\$out")"
fi
EOF
      chmod 755 "$f"
    done
  done
done
