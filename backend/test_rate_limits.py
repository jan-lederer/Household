"""Focused tests for per-client request limiting."""
import concurrent.futures
import unittest

import server


class RequestLimiterTests(unittest.TestCase):
    def test_limit_is_per_ip_and_endpoint_and_expires(self):
        limiter = server.RequestLimiter()
        self.assertTrue(limiter.allow('192.0.2.1', '/api/login', 2, 10, now=1))
        self.assertTrue(limiter.allow('192.0.2.1', '/api/login', 2, 10, now=2))
        self.assertFalse(limiter.allow('192.0.2.1', '/api/login', 2, 10, now=3))
        self.assertTrue(limiter.allow('192.0.2.2', '/api/login', 2, 10, now=3))
        self.assertTrue(limiter.allow('192.0.2.1', '/api/join', 2, 10, now=3))
        self.assertTrue(limiter.allow('192.0.2.1', '/api/login', 2, 10, now=11))

    def test_concurrent_requests_are_counted_atomically(self):
        limiter = server.RequestLimiter()
        with concurrent.futures.ThreadPoolExecutor(max_workers=24) as pool:
            accepted = list(pool.map(
                lambda _: limiter.allow('198.51.100.7', '/api/join', 7, 600, now=100),
                range(48),
            ))
        self.assertEqual(sum(accepted), 7)

    def test_client_state_is_bounded(self):
        limiter = server.RequestLimiter(max_keys=5)
        for index in range(100):
            self.assertTrue(limiter.allow(f'203.0.113.{index}', '/api/login', 1, 600, now=100))
        self.assertLessEqual(len(limiter._requests), 5)

    def test_protected_endpoints_have_expected_limits(self):
        self.assertEqual(server.RATE_LIMITS, {
            '/api/login': (30, 600),
            '/api/register': (30, 600),
            '/api/join': (20, 600),
        })


if __name__ == '__main__':
    unittest.main()
