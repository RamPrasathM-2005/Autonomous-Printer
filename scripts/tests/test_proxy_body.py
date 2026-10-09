import io
import unittest
from email.message import Message
from scripts.serve_frontend import Handler


class ProxyBodyTests(unittest.TestCase):
    def read(self, data, **headers):
        handler = object.__new__(Handler)
        handler.rfile = io.BytesIO(data)
        handler.headers = Message()
        for name, value in headers.items():
            handler.headers[name.replace('_', '-')] = value
        return handler.read_proxy_body()

    def test_empty_chunked_session(self):
        self.assertEqual(self.read(b'0\r\n\r\n', Transfer_Encoding='chunked'), b'')

    def test_chunked_upload_with_trailer(self):
        self.assertEqual(self.read(b'3\r\nabc\r\n2\r\nde\r\n0\r\nX-End: yes\r\n\r\n', Transfer_Encoding='chunked'), b'abcde')

    def test_content_length(self):
        self.assertEqual(self.read(b'abc', Content_Length='3'), b'abc')

    def test_ambiguous_framing(self):
        with self.assertRaises(ValueError):
            self.read(b'', Transfer_Encoding='chunked', Content_Length='0')

    def test_oversized_chunk(self):
        with self.assertRaises(OverflowError):
            self.read(b'4000000\r\n', Transfer_Encoding='chunked')

    def test_truncated_chunk(self):
        with self.assertRaises(ValueError):
            self.read(b'3\r\na', Transfer_Encoding='chunked')
