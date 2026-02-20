#!/usr/bin/env python3
"""
Test file for AI Reviewer
This file contains various code patterns for the AI reviewer to analyze.
"""

import os
import subprocess


class TestReviewer:
    """Test class to verify AI reviewer functionality."""

    def __init__(self):
        # Potential security issue: hardcoded password
        self.password = "admin123"
        self.api_key = "sk-test-key-12345"

    def eval_test(self, user_input):
        # Security issue: eval usage
        return eval(user_input)

    def execute_command(self, command):
        # Security issue: shell=True
        result = subprocess.run(command, shell=True, capture_output=True)
        return result

    def inefficient_loop(self, data):
        # Performance issue: O(n^2) nested loop
        result = []
        for item in data:
            for other in data:
                result.append(item + other)
        return result

    # TODO: Implement error handling
    # FIXME: This needs optimization
    def process_data(self, data):
        # Missing null check
        return data.upper()


if __name__ == "__main__":
    reviewer = TestReviewer()
    print(reviewer.process_data("test"))
