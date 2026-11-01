import socket
import sys
import os
import subprocess
import time

# Dynamically locate the tls/ directory whether invoked from root or this subfolder
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(SCRIPT_DIR, "tls")):
    TLS_DIR = os.path.join(SCRIPT_DIR, "tls")
else:
    TLS_DIR = os.path.join(SCRIPT_DIR, "..", "tls")
PASS_FRONT_PATH = os.path.join(TLS_DIR, "pass_front.py")

def check_and_start_pass_front():
    # Check if port 8443 is already listening
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', 8443))
        s.close()
        print("[✓] pass_front.py TLS front-end is ALREADY RUNNING (:8443)")
        return
    except Exception:
        pass

    # Start pass_front.py if found
    if os.path.exists(PASS_FRONT_PATH):
        try:
            print("[*] Starting pass_front.py in background (:8443 + :9443)...")
            log_file = open(os.path.join(TLS_DIR, "pass_front.log"), "a")
            proc = subprocess.Popen([sys.executable, PASS_FRONT_PATH],
                                    cwd=TLS_DIR,
                                    stdout=log_file,
                                    stderr=subprocess.STDOUT)
            time.sleep(1.5)
            s2 = socket.socket()
            s2.settimeout(1)
            try:
                s2.connect(('127.0.0.1', 8443))
                s2.close()
                print("[✓] pass_front.py successfully started on :8443 + :9443!")
            except Exception:
                print(f"[!] Note: pass_front.py spawned (pid {proc.pid}).")
        except Exception as e:
            print(f"[!] Warning: Could not auto-start pass_front.py: {e}")

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

TARGET_IP = sys.argv[1] if len(sys.argv) > 1 else get_local_ip()

print("=" * 60)
print(f"[*] Fake DNS Server Started")
print(f"[*] Redirecting all DNS queries to: {TARGET_IP}")
print(f"[*] Listening on UDP port 53...")
print("=" * 60)

check_and_start_pass_front()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

bound = False
for bind_addr in [('0.0.0.0', 53), (TARGET_IP, 53)]:
    try:
        sock.bind(bind_addr)
        print(f"[+] Successfully bound to {bind_addr[0]}:53")
        bound = True
        break
    except Exception as e:
        continue

if not bound:
    print("\n[!] ERROR: Port 53 is already in use by another program on Windows.")
    print("    Most common cause: Windows Mobile Hotspot is turned ON.")
    print("    -> Turn OFF 'Mobile hotspot' in Windows Settings and try again.")
    print("    -> Or close any other Python / DNS windows.")
    sys.exit(1)

while True:
    try:
        data, addr = sock.recvfrom(512)
        if len(data) < 12:
            continue

        tid = data[:2]
        flags = b'\x81\x80'
        counts = b'\x00\x01\x00\x01\x00\x00\x00\x00'

        idx = 12
        domain_parts = []
        while idx < len(data) and data[idx] != 0:
            length = data[idx]
            idx += 1
            domain_parts.append(data[idx:idx+length].decode(errors='ignore'))
            idx += length
        
        domain_name = ".".join(domain_parts)
        idx += 5
        question = data[12:idx]

        ip_bytes = socket.inet_aton(TARGET_IP)
        answer = b'\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04' + ip_bytes

        response = tid + flags + counts + question + answer
        sock.sendto(response, addr)
        print(f"[+] Spoofed query for '{domain_name}' from {addr[0]} -> {TARGET_IP}")

    except KeyboardInterrupt:
        print("\n[*] Stopping DNS server...")
        break
    except Exception as ex:
        print(f"[-] Error handling packet: {ex}")
