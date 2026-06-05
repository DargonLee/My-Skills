#!/usr/bin/env python3
"""
Xcode MCP Bridge Wrapper

Communicates with Apple's mcpbridge to interact with Xcode.
Bypasses MCP server schema validation issues by direct JSON-RPC calls.

Usage:
    python3 xcode_mcp_wrapper.py windows
    python3 xcode_mcp_wrapper.py open <file-path>
    python3 xcode_mcp_wrapper.py build [scheme]
"""

import json
import os
import select
import subprocess
import sys
import time

MCPBRIDGE_PATH = "/Applications/Xcode-26.5.0-Release.Candidate.app/Contents/Developer/usr/bin/mcpbridge"

class XcodeMCPClient:
    def __init__(self):
        self.proc = None
        self.request_id = 0

    def start(self):
        """Start mcpbridge process"""
        xcode_pid = os.environ.get("MCP_XCODE_PID", "")
        env = os.environ.copy()
        if xcode_pid:
            env["MCP_XCODE_PID"] = xcode_pid

        self.proc = subprocess.Popen(
            [MCPBRIDGE_PATH],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env
        )

        # Initialize MCP connection
        self._send_request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "xcode-mcp-wrapper", "version": "1.0"}
        })

        # Send initialized notification
        self._send_notification("notifications/initialized")

        # Give time for connection to establish
        time.sleep(0.5)

    def _send_request(self, method, params=None):
        """Send a JSON-RPC request"""
        self.request_id += 1
        msg = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def _send_notification(self, method, params=None):
        """Send a JSON-RPC notification (no id)"""
        msg = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params or {}
        }
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def _read_response(self, timeout=5):
        """Read response with timeout"""
        responses = []
        for _ in range(timeout * 10):
            time.sleep(0.1)
            while select.select([self.proc.stdout], [], [], 0)[0]:
                line = self.proc.stdout.readline()
                if line:
                    try:
                        resp = json.loads(line.strip())
                        responses.append(resp)
                    except json.JSONDecodeError:
                        pass
        return responses

    def call_tool(self, tool_name, arguments=None):
        """Call an MCP tool"""
        self._send_request("tools/call", {
            "name": tool_name,
            "arguments": arguments or {}
        })
        responses = self._read_response(timeout=10)

        # Find the tool result
        for resp in responses:
            if resp.get("id") == self.request_id:
                result = resp.get("result", {})
                if "content" in result:
                    for content in result["content"]:
                        if content.get("type") == "text":
                            return content.get("text", "")
                return result
        return None

    def list_tools(self):
        """List available MCP tools"""
        self._send_request("tools/list", {})
        responses = self._read_response(timeout=5)

        for resp in responses:
            if resp.get("id") == self.request_id:
                return resp.get("result", {}).get("tools", [])
        return None

    def stop(self):
        """Stop mcpbridge process"""
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()


def list_windows():
    """List open Xcode windows"""
    client = XcodeMCPClient()
    try:
        client.start()
        result = client.call_tool("XcodeListWindows")

        if result:
            # Parse and format the result
            try:
                data = json.loads(result)
                message = data.get("message", "")
                print("Xcode Windows:")
                print(message)
            except json.JSONDecodeError:
                print(result)
        else:
            print("No response from Xcode. Make sure Xcode is running.")

    finally:
        client.stop()


def open_file(file_path):
    """Open a file in Xcode"""
    client = XcodeMCPClient()
    try:
        client.start()

        # Resolve absolute path
        if not os.path.isabs(file_path):
            file_path = os.path.abspath(file_path)

        result = client.call_tool("XcodeOpenDocument", {
            "path": file_path
        })

        if result:
            print(f"Opened: {file_path}")
        else:
            print(f"Failed to open: {file_path}")

    finally:
        client.stop()


def build_project(scheme=None):
    """Build Xcode project"""
    # Use xcodebuild directly for building
    cmd = ["xcodebuild"]
    if scheme:
        cmd.extend(["-scheme", scheme])
    cmd.append("build")

    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nAvailable commands:")
        print("  windows  - List open Xcode windows")
        print("  open     - Open file in Xcode")
        print("  build    - Build Xcode project")
        print("  tools    - List available MCP tools (debug)")
        sys.exit(1)

    command = sys.argv[1]

    # Check if Xcode is running
    xcode_procs = subprocess.run(
        ["pgrep", "-x", "Xcode"],
        capture_output=True, text=True
    )
    if not xcode_procs.stdout.strip():
        print("Error: Xcode is not running. Please start Xcode first.")
        sys.exit(1)

    # Set Xcode PID
    os.environ["MCP_XCODE_PID"] = xcode_procs.stdout.strip().split()[0]

    if command == "windows":
        list_windows()
    elif command == "open":
        if len(sys.argv) < 3:
            print("Usage: python3 xcode_mcp_wrapper.py open <file-path>")
            sys.exit(1)
        open_file(sys.argv[2])
    elif command == "build":
        scheme = sys.argv[2] if len(sys.argv) > 2 else None
        build_project(scheme)
    elif command == "tools":
        # Debug: list available tools
        client = XcodeMCPClient()
        try:
            client.start()
            tools = client.list_tools()
            if tools:
                print("Available tools:")
                for tool in tools:
                    print(f"  - {tool.get('name')}: {tool.get('description', '')}")
            else:
                print("Could not retrieve tools list")
        finally:
            client.stop()
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()