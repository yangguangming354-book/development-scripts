#!/usr/bin/env python3
"""
脚本名称：network_scan.py
公司名称：Threatbook
作者：yangchuanwu
创建日期：2026-11-23
脚本用途：通过ICMP Ping并发探测指定IPv4网段中正在使用的地址。
"""

from __future__ import annotations

import argparse
import ipaddress
import platform
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed


DEFAULT_NETWORK = "172.23.80.0/24"


if platform.system() == "Windows":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="并发探测IPv4网段中能够响应Ping的地址。"
    )
    parser.add_argument(
        "network",
        nargs="?",
        default=DEFAULT_NETWORK,
        help=f"待扫描的IPv4网段，默认：{DEFAULT_NETWORK}",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=800,
        metavar="MS",
        help="单个地址的Ping超时时间（毫秒），默认：800",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=64,
        help="并发探测线程数，默认：64",
    )
    return parser.parse_args()


def build_ping_command(address: str, timeout_ms: int) -> list[str]:
    if platform.system() == "Windows":
        return ["ping", "-n", "1", "-w", str(timeout_ms), address]

    timeout_seconds = max(1, (timeout_ms + 999) // 1000)
    return ["ping", "-c", "1", "-W", str(timeout_seconds), address]


def ping(address: ipaddress.IPv4Address, timeout_ms: int) -> tuple[str, float] | None:
    command = build_ping_command(str(address), timeout_ms)
    start_time = time.perf_counter()

    try:
        result = subprocess.run(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=(timeout_ms / 1000) + 2,
            check=False,
            creationflags=(
                subprocess.CREATE_NO_WINDOW if platform.system() == "Windows" else 0
            ),
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    if result.returncode != 0:
        return None

    elapsed_ms = (time.perf_counter() - start_time) * 1000
    return str(address), elapsed_ms


def scan_network(
    network: ipaddress.IPv4Network, timeout_ms: int, workers: int
) -> list[tuple[str, float]]:
    active_hosts: list[tuple[str, float]] = []

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(ping, address, timeout_ms): address
            for address in network.hosts()
        }

        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                active_hosts.append(result)

    active_hosts.sort(key=lambda item: ipaddress.ip_address(item[0]))
    return active_hosts


def main() -> int:
    args = parse_arguments()

    try:
        network = ipaddress.ip_network(args.network, strict=False)
    except ValueError as error:
        print(f"错误：无效的网段：{error}", file=sys.stderr)
        return 2

    if network.version != 4:
        print("错误：当前脚本仅支持IPv4网段。", file=sys.stderr)
        return 2

    if args.timeout <= 0 or args.workers <= 0:
        print("错误：timeout和workers必须大于0。", file=sys.stderr)
        return 2

    print(f"开始扫描：{network}")
    print(f"地址数量：{network.num_addresses - 2}，并发数：{args.workers}")
    print("-" * 46)

    start_time = time.perf_counter()
    active_hosts = scan_network(network, args.timeout, args.workers)

    for index, (address, elapsed_ms) in enumerate(active_hosts, start=1):
        print(f"{index:>3}. {address:<15} 正在使用  响应耗时 {elapsed_ms:.0f} ms")

    total_seconds = time.perf_counter() - start_time
    print("-" * 46)
    print(f"扫描完成，共发现 {len(active_hosts)} 个响应地址，耗时 {total_seconds:.2f} 秒。")
    print("提示：禁用ICMP响应的设备可能无法通过Ping探测到。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
