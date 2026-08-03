#!/usr/bin/env python3
"""Test file with security issues for AI reviewer validation"""

# Security issue: Hardcoded password
DB_PASSWORD = "admin123"
API_KEY = "sk-1234567890abcdef"

def execute_user_input(user_input):
    # Security issue: eval() usage
    return eval(user_input)

def run_command(cmd):
    # Security issue: shell=True
    import subprocess
    return subprocess.run(cmd, shell=True, capture_output=True)

# TODO: Add input validation
# FIXME: Remove hardcoded credentials
def main():
    user_cmd = input("Enter command: ")
    execute_user_input(user_cmd)

if __name__ == "__main__":
    main()
