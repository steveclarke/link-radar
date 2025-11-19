/**
 * Privacy Protection Utilities
 *
 * Client-side filtering to prevent analysis of sensitive URLs:
 * - localhost addresses (localhost, 127.0.0.1, ::1)
 * - Private IPv4 ranges (10.x, 172.16.x, 192.168.x)
 * - Private IPv6 ranges (fc00::/7, fe80::/10)
 *
 * This is defense-in-depth: extension checks first (UX), backend validates second (security).
 * Provides immediate user feedback and prevents sensitive content from leaving browser.
 *
 * Uses ipaddr.js npm package for reliable IPv4/IPv6 classification.
 */

import * as ipaddr from "ipaddr.js"

/**
 * Check if URL is safe to analyze (allows public IPs and domains only)
 *
 * Blocks localhost and private IP addresses (127.0.0.1, 192.168.x.x, 10.x.x.x, etc.)
 * to prevent SSRF attacks. Domain names are allowed - backend validates via DNS.
 *
 * @param url - Full URL to validate
 * @returns true if safe to analyze, false if blocked (localhost/private)
 *
 * @example
 *   isSafeToAnalyze("https://example.com") // => true
 *   isSafeToAnalyze("http://192.168.1.1/") // => false
 */
export function isSafeToAnalyze(url: string): boolean {
  try {
    const urlObj = new URL(url)
    const hostname = urlObj.hostname

    // Check if hostname is a valid IP address
    if (!ipaddr.isValid(hostname)) {
      // Not an IP address (likely a domain name) - allow it
      // Backend will do final validation via DNS resolution
      return true
    }

    // Parse the IP address and check its range
    const addr = ipaddr.process(hostname)
    const range = addr.range()

    // Block private, loopback, and reserved ranges
    // ipaddr.range() returns values like:
    // - "private" (10.x, 172.16.x, 192.168.x for IPv4; fc00::/7 for IPv6)
    // - "loopback" (127.x for IPv4; ::1 for IPv6)
    // - "linkLocal" (169.254.x for IPv4; fe80:: for IPv6)
    // - "multicast", "reserved", etc.
    const blockedRanges = ["private", "loopback", "linkLocal", "multicast", "reserved"]
    if (blockedRanges.includes(range)) {
      return false
    }

    // All other ranges (including "unicast" for public IPs) are safe
    return true
  }
  catch {
    // URL parsing failed or IP validation error - allow it and let backend handle
    // This prevents client-side parsing issues from blocking legitimate URLs
    return true
  }
}
