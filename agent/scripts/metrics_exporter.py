#!/usr/bin/env python3
"""
Prometheus metrics exporter for agent network isolation monitoring.
Exposes iptables counters and traffic enforcement statistics.
"""

import os
import re
import time
import subprocess
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

from prometheus_client import Counter, Gauge, start_http_server

bypass_attempts_total = Counter(
    "agent_bypass_attempts_total",
    "Total number of blocked bypass attempts to internet",
    ["type"],
)

dns_bypass_attempts_total = Counter(
    "agent_dns_bypass_attempts_total",
    "Total number of blocked DNS bypass attempts",
    ["protocol"],
)

traffic_enforce_packets = Gauge(
    "agent_traffic_enforce_packets",
    "Packets processed by TRAFFIC_ENFORCE chain",
    ["chain", "rule"],
)

traffic_enforce_bytes = Gauge(
    "agent_traffic_enforce_bytes",
    "Bytes processed by TRAFFIC_ENFORCE chain",
    ["chain", "rule"],
)

network_isolation_status = Gauge(
    "agent_network_isolation_status",
    "Network isolation enforcement status (1=enabled, 0=disabled)",
)

allowed_destinations = Gauge(
    "agent_allowed_destinations",
    "Number of allowed destination rules in firewall",
)

active_connections = Gauge(
    "agent_active_connections", "Number of active TCP connections", ["state"]
)

last_bypass_log = Gauge(
    "agent_last_bypass_log_timestamp",
    "Timestamp of last bypass attempt in kernel log (0 if none)",
)


def parse_iptables_counters() -> None:
    """Parse iptables -L -n -v output for packet/byte counters."""
    try:
        result = subprocess.run(
            ["iptables", "-L", "TRAFFIC_ENFORCE", "-n", "-v", "-x"],
            capture_output=True,
            text=True,
            timeout=5,
        )

        lines = result.stdout.strip().split("\n")
        rule_pattern = re.compile(r"^\s*(\d+)\s+(\d+)\s+(ACCEPT|DROP|LOG)\s+")

        bypass_count = 0
        dns_bypass_count = 0
        allowed_rules = 0
        rule_idx = 0

        for line in lines[2:]:
            match = rule_pattern.match(line)
            if match:
                packets = int(match.group(1))
                bytes_val = int(match.group(2))
                action = match.group(3)

                rule_name = f"rule_{rule_idx}"
                if "proxy" in line.lower() or "172.30.0.2" in line:
                    rule_name = "proxy"
                elif "DROP" in action and "dpt:53" in line:
                    rule_name = "dns_block"
                elif "LOG" in action and "BYPASS" in line:
                    rule_name = "bypass_log"
                elif "LOG" in action and "DNS" in line:
                    rule_name = "dns_log"
                elif "DROP" in action and rule_idx == len(lines[2:]) - 1:
                    rule_name = "default_drop"

                traffic_enforce_packets.labels(
                    chain="TRAFFIC_ENFORCE", rule=rule_name
                ).set(packets)
                traffic_enforce_bytes.labels(
                    chain="TRAFFIC_ENFORCE", rule=rule_name
                ).set(bytes_val)

                if (
                    action == "DROP"
                    and "dpt:53" not in line
                    and rule_idx == len(lines[2:]) - 1
                ):
                    bypass_count = packets
                elif action == "DROP" and "dpt:53" in line:
                    dns_bypass_count = packets

                if action == "ACCEPT":
                    allowed_rules += 1

                rule_idx += 1

        bypass_attempts_total.labels(type="internet").inc(bypass_count)
        dns_bypass_attempts_total.labels(protocol="tcp").inc(dns_bypass_count)
        allowed_destinations.set(allowed_rules)

    except Exception as e:
        logger.error(f"Error parsing iptables: {e}")


def check_isolation_enabled() -> None:
    """Check if traffic enforcement is enabled."""
    try:
        result = subprocess.run(
            ["iptables", "-L", "TRAFFIC_ENFORCE", "-n"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        enabled = 1 if "TRAFFIC_ENFORCE" in result.stdout else 0
        network_isolation_status.set(enabled)
    except Exception as e:
        network_isolation_status.set(0)
        logger.error(f"Error checking isolation: {e}")


def count_connections() -> None:
    """Count TCP connections by state."""
    try:
        with open("/proc/net/tcp", "r") as f:
            lines = f.readlines()[1:]

        states = {
            "01": "ESTABLISHED",
            "02": "SYN_SENT",
            "03": "SYN_RECV",
            "04": "FIN_WAIT1",
            "05": "FIN_WAIT2",
            "06": "TIME_WAIT",
            "07": "CLOSE",
            "08": "CLOSE_WAIT",
            "09": "LAST_ACK",
            "0A": "LISTEN",
            "0B": "CLOSING",
        }

        state_counts = {}
        for line in lines:
            parts = line.split()
            if len(parts) >= 4:
                state_hex = parts[3]
                state_name = states.get(state_hex, "UNKNOWN")
                state_counts[state_name] = state_counts.get(state_name, 0) + 1

        for state_name in states.values():
            active_connections.labels(state=state_name).set(
                state_counts.get(state_name, 0)
            )

    except Exception as e:
        logger.error(f"Error counting connections: {e}")


def check_kernel_log_for_bypass() -> None:
    """Check kernel log for bypass attempts."""
    try:
        result = subprocess.run(["dmesg"], capture_output=True, text=True, timeout=5)

        bypass_lines = [l for l in result.stdout.split("\n") if "BYPASS-ATTEMPT" in l]
        if bypass_lines:
            bypass_attempts_total.labels(type="internet").inc(len(bypass_lines))

        dns_lines = [l for l in result.stdout.split("\n") if "DNS-BLOCK" in l]
        if dns_lines:
            dns_bypass_attempts_total.labels(protocol="udp").inc(len(dns_lines))

    except Exception as e:
        logger.error(f"Error checking kernel log: {e}")


def main() -> None:
    """Main metrics collection loop."""
        logger.info(f"Starting metrics exporter on port {METRICS_PORT}")
    start_http_server(METRICS_PORT)

    while True:
        parse_iptables_counters()
        check_isolation_enabled()
        count_connections()
        check_kernel_log_for_bypass()
        time.sleep(10)


if __name__ == "__main__":
    main()
