#!/usr/bin/env python3
"""One fresh iPhone still photo per Mac/Windows request, over trusted LAN HTTP.

Python standard library only. Saves latest.jpg atomically; no MJPEG/video stream.
A failed capture leaves the last JPEG on disk for inspection but never reports
it as fresh. Integrate the returned new bytes into RPA only after success.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sys
import time
from urllib import request, error
import uuid
import ipaddress
from urllib.parse import urlparse

MAX_JPEG_BYTES = 20 * 1024 * 1024
LAN_RANGES = [ipaddress.ip_network(n) for n in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8')]


def validate_lan_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme != 'http' or not parsed.hostname or parsed.username is not None or parsed.password is not None:
        raise ValueError('Expected http://<private-ip>:8080 (no credentials in URL)')
    if parsed.path not in ('', '/') or parsed.query or parsed.fragment:
        raise ValueError('Use base URL only, without path/query')
    if parsed.port != 8080 and parsed.hostname not in ('127.0.0.1', 'localhost'):
        raise ValueError('Expected camera HTTP port 8080')
    try:
        ip = ipaddress.ip_address(parsed.hostname)
    except ValueError as exc:
        if parsed.hostname != 'localhost':
            raise ValueError('Use the numeric Wi-Fi IPv4 address of the iPhone') from exc
    else:
        if ip.version != 4 or not any(ip in net for net in LAN_RANGES):
            raise ValueError('Camera URL must be private IPv4 or localhost')
    return url.rstrip('/')



def take_photo(base_url: str, token: str, timeout: float = 17.0) -> tuple[bytes, str, str]:
    url = validate_lan_url(base_url) + '/shot.jpg'
    req = request.Request(
        url,
        headers={'X-RPA-Token': token, 'Cache-Control': 'no-store'},
        method='GET',
    )
    with request.urlopen(req, timeout=timeout) as response:
        if response.status != 200:
            raise RuntimeError(f'Unexpected HTTP {response.status}')
        if response.headers.get_content_type() != 'image/jpeg':
            raise RuntimeError('Device returned something other than image/jpeg')
        capture_id = response.headers.get('X-Capture-Id', '')
        captured_at = response.headers.get('X-Captured-At', '')
        if not capture_id or not captured_at:
            raise RuntimeError('Missing fresh-photo proof headers')
        raw = response.read(MAX_JPEG_BYTES + 1)
        if len(raw) > MAX_JPEG_BYTES:
            raise RuntimeError('Photo exceeds 20MB safety limit')
        if len(raw) < 32 or not raw.startswith(b'\xff\xd8') or not raw.endswith(b'\xff\xd9'):
            raise RuntimeError('Incomplete / invalid JPEG response')
        return raw, capture_id, captured_at


def atomic_save(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        temporary.write_bytes(data)
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description='iPhone LAN periodic full-resolution photos (no video)')
    p.add_argument('--token', default=os.getenv('RPA_SNAPSHOT_TOKEN'),
                   help='Token shown in iPhone app (or env RPA_SNAPSHOT_TOKEN)')
    p.add_argument('--url', required=True,
                   help='iPhone URL: http://192.168.0.10:8080 (your phone IP)')
    p.add_argument('--interval', type=float, default=5.0,
                   help='Seconds between the starts of requests (default 5)')
    p.add_argument('--count', type=int, default=0,
                   help='Attempts to make then exit (0 = continuous)')
    p.add_argument('--output', type=Path, default=Path('latest.jpg'),
                   help='Atomic path to latest successfully fetched JPEG')
    p.add_argument('--archive', type=Path, default=None,
                   help='Optional directory to retain every photo for POC evidence')
    p.add_argument('--log', type=Path, default=None,
                   help='Optional JSONL log of success/error and capture IDs')
    args = p.parse_args(argv)
    if not args.token:
        p.error('Missing --token or RPA_SNAPSHOT_TOKEN')
    if not (1.0 <= args.interval <= 120.0):
        p.error('--interval must be between 1 and 120 seconds')
    if args.count < 0:
        p.error('--count must be nonnegative')
    try:
        args.url = validate_lan_url(args.url)
    except ValueError as exc:
        p.error(str(exc))
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    print(f'Snapshot polling: {args.url} every {args.interval:g}s -> {args.output}', flush=True)
    attempted = 0
    errors = 0
    previous_capture_id = ''
    next_deadline = time.monotonic()
    try:
        while not args.count or attempted < args.count:
            now = time.monotonic()
            if now < next_deadline:
                time.sleep(next_deadline - now)
            began = time.monotonic()
            attempted += 1
            row = {'attempt': attempted, 'requested_at': dt.datetime.now(dt.timezone.utc).isoformat()}
            try:
                jpeg, capture_id, captured_at = take_photo(args.url, args.token)
                if capture_id == previous_capture_id:
                    raise RuntimeError('Old capture ID was returned (stale photo)')
                previous_capture_id = capture_id
                atomic_save(args.output, jpeg)
                if args.archive:
                    unique_name = f"{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')}_{capture_id[:8]}.jpg"
                    atomic_save(args.archive / unique_name, jpeg)
                elapsed = time.monotonic() - began
                row.update(status='ok', captured_at=captured_at, capture_id=capture_id,
                           bytes=len(jpeg), duration_sec=round(elapsed, 3))
                print(f"[{attempted}] NEW photo {len(jpeg):,} bytes, {elapsed:.2f}s -> {args.output}", flush=True)
                # RPA hook: process this JPEG only on success. Do not mistake
                # filesystem old latest.jpg for a new capture if polling failed.
            except (OSError, error.URLError, RuntimeError, TimeoutError) as exc:
                errors += 1
                row.update(status='error', error=str(exc))
                print(f'[{attempted}] PHOTO FAILED: {exc}', file=sys.stderr, flush=True)
            if args.log:
                args.log.parent.mkdir(parents=True, exist_ok=True)
                with args.log.open('a', encoding='utf-8') as f:
                    f.write(json.dumps(row, ensure_ascii=False) + '\n')
            next_deadline = max(began + args.interval, time.monotonic())
    except KeyboardInterrupt:
        print('\nStopped by user.', flush=True)
    print(f'Attempts={attempted} failures={errors}', flush=True)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
