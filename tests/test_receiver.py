"""No actual iPhone required: fake HTTP responses exercise snapshot Mac client."""
import os
import pathlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import tempfile
import threading
import unittest
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'Host'))
from poll_snapshots import take_photo, atomic_save, validate_lan_url

# Smallest useful RGB JPEG generated with Pillow once and embedded as bytes in test,
# so production and tests have no third-party Python dependencies.
import base64
VALID_JPEG = base64.b64decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcU'
    'FhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgo'
    'KCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIA'
    'AhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAbEAABBAMAAAAAAAAAAAAAAAAFAQIDBBEh'
    'Mf/EABUBAQEAAAAAAAAAAAAAAAAAAAQF/8QAGBEAAwEBAAAAAAAAAAAAAAAAAAECESH/2gAMAwEA'
    'AhEDEQA/AKfyquwjEPU2KqR3DkOmG0s3PT0ktJtEP//Z'
)


class TestHandler(BaseHTTPRequestHandler):
    seq = 0

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path != '/shot.jpg':
            self.send_error(404)
            return
        if self.headers.get('X-RPA-Token') != 'local-test':
            self.send_error(403)
            return
        TestHandler.seq += 1
        self.send_response(200)
        self.send_header('Content-Type', 'image/jpeg')
        self.send_header('Content-Length', str(len(VALID_JPEG)))
        self.send_header('X-Capture-Id', str(TestHandler.seq))
        self.send_header('X-Captured-At', '2026-10-26T10:00:00Z')
        self.end_headers()
        self.wfile.write(VALID_JPEG)


class CameraClientTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), TestHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def test_lan_url_validation(self):
        self.assertEqual(validate_lan_url("http://192.168.0.10:8080"), "http://192.168.0.10:8080")
        with self.assertRaises(ValueError):
            validate_lan_url("http://8.8.8.8:8080")
        with self.assertRaises(ValueError):
            validate_lan_url("https://192.168.0.10:8080")

    def test_two_separate_capture_ids(self):
        url = f'http://127.0.0.1:{self.server.server_port}'
        j1, c1, _ = take_photo(url, 'local-test')
        j2, c2, _ = take_photo(url, 'local-test')
        self.assertNotEqual(c1, c2)
        self.assertTrue(j1.startswith(b'\xff\xd8'))
        self.assertEqual(j1, j2)  # same scene is valid; capture ID is unique

    def test_wrong_token(self):
        url = f'http://127.0.0.1:{self.server.server_port}'
        with self.assertRaises(Exception):
            take_photo(url, 'wrong')

    def test_atomic_replace(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / 'latest.jpg'
            atomic_save(target, VALID_JPEG)
            self.assertEqual(target.read_bytes(), VALID_JPEG)
            self.assertEqual(list(pathlib.Path(directory).glob('*.tmp')), [])


if __name__ == '__main__':
    unittest.main()
