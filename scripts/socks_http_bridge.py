#!/usr/bin/env python3
"""Minimal HTTP CONNECT / absolute-URI proxy that forwards via SOCKS5.

Used so depot_tools vpython/pip (no SOCKS support) can talk through a local
HTTP proxy that hops into an existing SOCKS5 upstream (e.g. Clash).
"""
from __future__ import annotations

import argparse
import select
import socket
import threading

import socks


def relay(a: socket.socket, b: socket.socket) -> None:
    try:
        while True:
            r, _, _ = select.select([a, b], [], [], 60)
            if not r:
                break
            for src in r:
                dst = b if src is a else a
                data = src.recv(65536)
                if not data:
                    return
                dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            a.close()
        except OSError:
            pass
        try:
            b.close()
        except OSError:
            pass


def handle(client: socket.socket, upstream_host: str, upstream_port: int) -> None:
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = client.recv(4096)
            if not chunk:
                return
            req += chunk
        head, _, rest = req.partition(b"\r\n\r\n")
        lines = head.split(b"\r\n")
        request_line = lines[0].decode("latin1", errors="replace")
        method, target, _ = request_line.split(" ", 2)

        remote = socks.socksocket()
        remote.set_proxy(socks.SOCKS5, upstream_host, upstream_port)

        if method.upper() == "CONNECT":
            host, port_s = target.split(":")
            remote.connect((host, int(port_s)))
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            if rest:
                remote.sendall(rest)
        else:
            # absolute-form: GET http://host/path HTTP/1.1
            if not target.startswith("http://"):
                client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
                return
            without = target[len("http://") :]
            host_port, _, path = without.partition("/")
            if ":" in host_port:
                host, port_s = host_port.split(":")
                port = int(port_s)
            else:
                host, port = host_port, 80
            path = "/" + path
            remote.connect((host, port))
            lines[0] = f"{method} {path} HTTP/1.1".encode("latin1")
            new_head = b"\r\n".join(lines) + b"\r\n\r\n" + rest
            remote.sendall(new_head)

        t = threading.Thread(target=relay, args=(client, remote), daemon=True)
        t.start()
        t.join()
    except Exception:
        try:
            client.close()
        except OSError:
            pass


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", default="127.0.0.1:18080")
    ap.add_argument("--socks", default="127.0.0.1:10808")
    args = ap.parse_args()
    lhost, lport = args.listen.rsplit(":", 1)
    shost, sport = args.socks.rsplit(":", 1)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((lhost, int(lport)))
    srv.listen(128)
    print(f"http-proxy {lhost}:{lport} -> socks5://{shost}:{sport}", flush=True)
    while True:
        c, _ = srv.accept()
        threading.Thread(
            target=handle, args=(c, shost, int(sport)), daemon=True
        ).start()


if __name__ == "__main__":
    main()
