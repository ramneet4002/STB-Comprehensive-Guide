import socket
import struct
import threading
import sys
import os
import subprocess
import time

SERVER_IP = "192.168.10.1"
CLIENT_IP = "192.168.10.2"
SUBNET_MASK = "255.255.255.0"
BROADCAST_IP = "192.168.10.255"

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
            # Verify port 8443 is now open
            s2 = socket.socket()
            s2.settimeout(1)
            try:
                s2.connect(('127.0.0.1', 8443))
                s2.close()
                print(f"[✓] pass_front.py successfully started (PID {proc.pid}) on :8443 + :9443!")
            except Exception:
                print("[-] pass_front.py launched, waiting for it to bind ports...")
        except Exception as ex:
            print(f"[!] Could not auto-launch pass_front.py: {ex}")
    else:
        print(f"[!] Could not locate pass_front.py at {PASS_FRONT_PATH}")

def check_genieacs():
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', 7557))
        s.close()
        print("[✓] GenieACS NBI is RUNNING (http://127.0.0.1:7557)")
    except Exception:
        print("[!] WARNING: GenieACS NBI (:7557) is NOT reachable!")
        print("    Make sure Docker Desktop is open and run: cd tls && docker compose up -d")

    s2 = socket.socket()
    s2.settimeout(1)
    try:
        s2.connect(('127.0.0.1', 7547))
        s2.close()
        print("[✓] GenieACS CWMP is RUNNING (:7547)")
    except Exception:
        print("[!] WARNING: GenieACS CWMP (:7547) is NOT reachable!")

def run_http_portal():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind(('0.0.0.0', 80))
        sock.listen(10)
        print("[*] Captive Portal server listening on port 80 (HTTP 204 responder)...")
    except Exception as e:
        print(f"[-] HTTP port 80 bind notice: {e}")
        return

    while True:
        try:
            client, addr = sock.accept()
            _ = client.recv(1024)
            resp = b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            client.sendall(resp)
            client.close()
            print(f"[+] Answered HTTP 204 (Connectivity Check) for {addr[0]}")
        except Exception:
            pass

def run_dhcp():
    recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    recv_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    recv_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        recv_sock.bind(('0.0.0.0', 67))
        print("[*] DHCP Server listening on port 67...")
    except PermissionError:
        print("[!] ERROR: Run terminal / PowerShell as Administrator to bind port 67!")
        return
    except Exception as e:
        print(f"[!] DHCP bind error: {e}")
        return

    send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    send_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    send_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        send_sock.bind((SERVER_IP, 67))
    except Exception:
        send_sock = recv_sock

    while True:
        try:
            data, addr = recv_sock.recvfrom(1024)
            if len(data) < 240:
                continue

            if data[236:240] != b'\x63\x82\x53\x63':
                continue

            xid = data[4:8]
            flags = data[10:12]
            client_mac = data[28:44]
            mac_hex = ':'.join(f'{b:02x}' for b in data[28:34])

            msg_type = None
            idx = 240
            while idx < len(data) and data[idx] != 0xff:
                opt = data[idx]
                if opt == 0:
                    idx += 1
                    continue
                length = data[idx+1]
                if opt == 53 and length == 1:
                    msg_type = data[idx+2]
                    break
                idx += 2 + length

            resp_type = None
            if msg_type == 1:
                resp_type = 2
                print(f"[+] Received DHCP Discover from STB ({mac_hex})! Sending Offer ({CLIENT_IP})...")
            elif msg_type == 3:
                resp_type = 5
                print(f"[+] Received DHCP Request from STB ({mac_hex})! Sending Ack ({CLIENT_IP})...")
            else:
                continue

            op = b'\x02'
            htype = b'\x01'
            hlen = b'\x06'
            hops = b'\x00'
            secs = b'\x00\x00'
            ciaddr = b'\x00\x00\x00\x00'
            yiaddr = socket.inet_aton(CLIENT_IP)
            siaddr = b'\x00\x00\x00\x00'
            giaddr = b'\x00\x00\x00\x00'
            chaddr = client_mac
            sname = b'\x00' * 64
            file = b'\x00' * 128
            cookie = b'\x63\x82\x53\x63'

            options = bytearray()
            options += bytes([53, 1, resp_type])
            options += bytes([54, 4]) + socket.inet_aton(SERVER_IP)
            options += bytes([51, 4]) + struct.pack('>I', 86400)
            options += bytes([58, 4]) + struct.pack('>I', 43200)
            options += bytes([59, 4]) + struct.pack('>I', 75600)
            options += bytes([1, 4]) + socket.inet_aton(SUBNET_MASK)
            options += bytes([28, 4]) + socket.inet_aton(BROADCAST_IP)
            options += bytes([3, 4]) + socket.inet_aton(SERVER_IP)
            options += bytes([6, 4]) + socket.inet_aton(SERVER_IP)
            options += b'\xff'

            packet = op + htype + hlen + hops + xid + secs + flags + ciaddr + yiaddr + siaddr + giaddr + chaddr + sname + file + cookie + bytes(options)

            # CRITICAL: RFC 2131 / RFC 1542 minimum packet size = 300 octets.
            # Android dhcpcd/DhcpPacket silently drops packets smaller than 300 bytes!
            if len(packet) < 300:
                packet += b'\x00' * (300 - len(packet))

            for sock in [send_sock, recv_sock]:
                for target in ['255.255.255.255', BROADCAST_IP, CLIENT_IP]:
                    try:
                        sock.sendto(packet, (target, 68))
                    except Exception:
                        pass

            if resp_type == 5:
                print(f"[✓] STB successfully assigned IP {CLIENT_IP} and DNS {SERVER_IP}!")

        except Exception as ex:
            print(f"[-] DHCP error: {ex}")

def run_dns():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind(('0.0.0.0', 53))
        print("[*] DNS Server listening on port 53...")
    except PermissionError:
        print("[!] ERROR: Run terminal / PowerShell as Administrator to bind port 53!")
        return
    except Exception as e:
        print(f"[!] DNS bind error: {e}")
        return

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

            ip_bytes = socket.inet_aton(SERVER_IP)
            answer = b'\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04' + ip_bytes

            response = tid + flags + counts + question + answer
            sock.sendto(response, addr)
            print(f"[+] Resolved DNS for '{domain_name}' from {addr[0]} -> {SERVER_IP}")
        except Exception as ex:
            print(f"[-] DNS error: {ex}")

if __name__ == '__main__':
    print("=" * 60)
    print("   Jio STB Direct Ethernet Helper (DHCP + DNS + Front-End)")
    print(f"   PC IP:        {SERVER_IP}")
    print(f"   STB IP:       {CLIENT_IP}")
    print(f"   Broadcast IP: {BROADCAST_IP}")
    print("=" * 60)

    # Check services and start pass_front
    check_genieacs()
    check_and_start_pass_front()

    t_dhcp = threading.Thread(target=run_dhcp, daemon=True)
    t_dns = threading.Thread(target=run_dns, daemon=True)
    t_portal = threading.Thread(target=run_http_portal, daemon=True)

    t_dhcp.start()
    t_dns.start()
    t_portal.start()

    print("\n[✓] Services active. Keep this window running!")
    print("    Now reboot STB (if needed) and run stage1.sh in Git Bash.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[*] Exiting...")
