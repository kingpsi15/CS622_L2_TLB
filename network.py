import datetime, re, ssl, time, urllib.parse, urllib.request

USER = "sahilag24"
PWD = "Mathsisbest@1"
CHECK_INTERVAL = 120  # check every 2 minutes

ctx = ssl._create_unverified_context()
opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))

def now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def get_field(html, field):
    tag = re.search(rf'<input[^>]*name=["\']{re.escape(field)}["\'][^>]*>', html, re.I)
    if not tag:
        return None
    val = re.search(r'value=["\']([^"\']*)["\']', tag.group(0), re.I)
    return val.group(1) if val else None

def is_online():
    try:
        req = urllib.request.Request("http://neverssl.com", headers={"Cache-Control": "no-cache"})
        html = opener.open(req, timeout=10).read().decode("utf-8", errors="ignore")
        return "fgtauth" not in html
    except Exception:
        return False

def login():
    req = urllib.request.Request("http://neverssl.com", headers={"Cache-Control": "no-cache"})
    html = opener.open(req, timeout=10).read().decode("utf-8", errors="ignore")
    if "fgtauth" not in html:
        return True
    m_js = re.search(r'window\.location\s*=\s*["\']([^"\']+)["\']', html)
    if not m_js:
        raise RuntimeError("Portal redirect URL not found")
    form_html = opener.open(m_js.group(1), timeout=10).read().decode("utf-8", errors="ignore")
    magic = get_field(form_html, "magic")
    redir = get_field(form_html, "4Tredir") or "http://neverssl.com"
    if not magic:
        raise RuntimeError("Magic token not found")
    data = urllib.parse.urlencode({
        "4Tredir": redir,
        "magic": magic,
        "username": USER,
        "password": PWD,
    }).encode()
    res_html = opener.open("https://gateway.iitk.ac.in:1003/", data=data, timeout=10).read().decode("utf-8", errors="ignore")
    if not is_online():
        return False
    ka = re.search(r'(https://gateway\.iitk\.ac\.in:1003/keepalive\?[^"\'\s<]+)', res_html)
    return ka.group(1) if ka else True

ka_url = None
while True:
    if ka_url:
        try:
            opener.open(ka_url, timeout=10).read()
        except Exception:
            ka_url = None

    if not is_online():
        print(f"[{now()}] Session expired or offline. Re-authenticating...")
        try:
            res = login()
            if res is False:
                print(f"[{now()}] Login rejected. Retrying in {CHECK_INTERVAL}s...")
                ka_url = None
            else:
                ka_url = res if isinstance(res, str) else None
                print(f"[{now()}] Connected!")
        except Exception as e:
            print(f"[{now()}] Error: {e}. Retrying in {CHECK_INTERVAL}s...")
            ka_url = None

    time.sleep(CHECK_INTERVAL)
