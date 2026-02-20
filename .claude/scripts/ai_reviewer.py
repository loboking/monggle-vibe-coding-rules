#!/usr/bin/env python3
"""
AI Reviewer - Automated Code Review System

Part of monggle-vibe-coding-rules
Reviews PRs/MRs using AI models (GPT-4, Claude, etc.)

Usage:
    python3 ai_reviewer.py --pr-url <url> [--mode <mode>]
    python3 ai_reviewer.py --diff <file> [--output <file>]
"""

import os
import sys
import json
import argparse
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# Try to import Anthropic (Claude), OpenAI as fallback
try:
    import anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False
    print("Warning: anthropic package not installed. Install with: pip install anthropic")

try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("Warning: openai package not installed. Install with: pip install openai")


class ReviewMode(Enum):
    """Review mode enumeration"""
    MANUAL = "manual"
    SEMI_AUTO = "semi-auto"
    AUTO = "auto"


class ReviewStatus(Enum):
    """Review result status"""
    APPROVED = "approved"
    CHANGES_REQUESTED = "changes_requested"
    ERROR = "error"
    SKIPPED = "skipped"


@dataclass
class ReviewResult:
    """Review result dataclass"""
    status: ReviewStatus
    confidence: float
    feedback: str
    issues: List[Dict]
    metadata: Dict


class AIReviewer:
    """AI Reviewer main class"""

    def __init__(self, config_path: Optional[Path] = None):
        """Initialize AI Reviewer with configuration"""
        self.project_root = Path(__file__).parent.parent.parent
        self.config_path = config_path or (self.project_root / ".claude" / "config" / "team.yaml")
        self.config = self._load_config()

        # Try Claude (Anthropic) first, then OpenAI
        ai_config = self.config.get("ai_reviewer", {})
        self.model = ai_config.get("model", "claude-opus-4")

        if "claude" in self.model.lower() or "anthropic" in self.model.lower():
            self.api_key = os.environ.get(ai_config.get("api_key_env", "ANTHROPIC_API_KEY"))
            self.api_provider = "anthropic"
        else:
            self.api_key = os.environ.get(ai_config.get("api_key_env", "OPENAI_API_KEY"))
            self.api_provider = "openai"

        if not self.api_key:
            print(f"Warning: API key not found. Set {self.config.get('ai_reviewer', {}).get('api_key_env', 'ANTHROPIC_API_KEY')} environment variable.")

    def _load_config(self) -> Dict:
        """Load configuration from YAML file"""
        try:
            import yaml
            if self.config_path.exists():
                with open(self.config_path) as f:
                    return yaml.safe_load(f)
        except ImportError:
            print("Warning: PyYAML not installed. Using default config.")
        except Exception as e:
            print(f"Warning: Failed to load config: {e}")

        # Return default configuration
        return {
            "ai_reviewer": {
                "enabled": True,
                "mode": "manual",
                "model": "claude-opus-4",
                "api_key_env": "ANTHROPIC_API_KEY",
                "auto_merge_threshold": 0.9,
                "checks": ["security", "performance", "best_practices"],
                "no_auto_merge": {"paths": ["prod/*"], "keywords": ["TODO", "HACK"]}
            }
        }

    def review_diff(self, diff: str, file_path: Optional[str] = None) -> ReviewResult:
        """Review a code diff using AI"""

        if not diff or not diff.strip():
            return ReviewResult(
                status=ReviewStatus.SKIPPED,
                confidence=0.0,
                feedback="No diff to review",
                issues=[],
                metadata={}
            )

        # Check if path is in no_auto_merge list
        if file_path:
            for excluded_path in self.config.get("ai_reviewer", {}).get("no_auto_merge", {}).get("paths", []):
                if file_path.startswith(excluded_path.rstrip("*")):
                    return ReviewResult(
                        status=ReviewStatus.CHANGES_REQUESTED,
                        confidence=1.0,
                        feedback=f"File path {file_path} is excluded from auto-merge",
                        issues=[{"type": "path_exclusion", "message": f"Protected path: {excluded_path}"}],
                        metadata={"file": file_path}
                    )

        # Prepare the review prompt
        checks = self.config.get("ai_reviewer", {}).get("checks", [])
        prompt = self._build_review_prompt(diff, checks)

        # Call AI API
        try:
            if self.api_key:
                if self.api_provider == "anthropic" and ANTHROPIC_AVAILABLE:
                    analysis = self._call_claude(prompt)
                elif self.api_provider == "openai" and OPENAI_AVAILABLE:
                    analysis = self._call_openai(prompt)
                else:
                    # Fallback to rule-based analysis
                    analysis = self._rule_based_analysis(diff, checks)
            else:
                # Fallback to rule-based analysis
                analysis = self._rule_based_analysis(diff, checks)

            # Parse analysis and calculate confidence
            return self._parse_analysis(analysis)

        except Exception as e:
            return ReviewResult(
                status=ReviewStatus.ERROR,
                confidence=0.0,
                feedback=f"Review failed: {str(e)}",
                issues=[],
                metadata={"error": str(e)}
            )

    def _build_review_prompt(self, diff: str, checks: List[str]) -> str:
        """Build the review prompt for AI"""
        checks_desc = ", ".join(checks)

        prompt = f"""You are an expert code reviewer. Review the following code changes for:
{checks_desc}

Code diff:
```
{diff}
```

Provide your review in the following JSON format:
{{
    "status": "approved" | "changes_requested",
    "confidence": 0.0-1.0,
    "summary": "Brief summary of the review",
    "issues": [
        {{
            "type": "security|performance|best_practices|documentation|error_handling",
            "severity": "high|medium|low",
            "line": null or number,
            "message": "Description of the issue"
        }}
    ]
}}

Focus on:
1. Security vulnerabilities (injection, XSS, authentication issues)
2. Performance problems (inefficient algorithms, N+1 queries)
3. Code quality and best practices
4. Test coverage gaps
5. Documentation completeness
6. Error handling

Be thorough but constructive. If the code is good, approve it with high confidence.
"""
        return prompt

    def _call_claude(self, prompt: str) -> str:
        """Call Anthropic Claude API for review"""
        import anthropic

        client = anthropic.Anthropic(api_key=self.api_key)
        model = self.config.get("ai_reviewer", {}).get("model", "claude-opus-4")

        # Map friendly names to actual model IDs
        model_mapping = {
            "claude-opus-4": "claude-3-5-sonnet-20241022",
            "claude-sonnet-4": "claude-3-5-sonnet-20241022",
            "claude-haiku-4": "claude-3-5-haiku-20241022",
        }
        actual_model = model_mapping.get(model, model)

        response = client.messages.create(
            model=actual_model,
            max_tokens=2000,
            temperature=0.3,
            system="You are an expert code reviewer. Provide reviews in JSON format.",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        return response.content[0].text

    def _call_openai(self, prompt: str) -> str:
        """Call OpenAI API for review"""
        import openai

        client = openai.OpenAI(api_key=self.api_key)
        model = self.config.get("ai_reviewer", {}).get("model", "gpt-4")

        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are an expert code reviewer. Provide reviews in JSON format."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=2000
        )

        return response.choices[0].message.content

    def _rule_based_analysis(self, diff: str, checks: List[str]) -> str:
        """Fallback rule-based analysis when AI is not available"""

        issues = []
        keywords = self.config.get("ai_reviewer", {}).get("no_auto_merge", {}).get("keywords", [])

        # Check for keywords
        for keyword in keywords:
            if keyword in diff:
                issues.append({
                    "type": "best_practices",
                    "severity": "medium",
                    "line": None,
                    "message": f"Found keyword '{keyword}' in diff"
                })

        # Basic security checks
        if "security" in checks:
            security_patterns = [
                (r"eval\s*\(", "Use of eval() is dangerous"),
                (r"exec\s*\(", "Use of exec() is dangerous"),
                (r"shell=True", "shell=True is vulnerable to injection"),
                (r"password\s*=\s*['\"][^'\"]+['\"]", "Hardcoded password detected"),
            ]

            for pattern, message in security_patterns:
                if re.search(pattern, diff, re.IGNORECASE):
                    issues.append({
                        "type": "security",
                        "severity": "high",
                        "line": None,
                        "message": message
                    })

        # Determine status based on issues
        high_severity_issues = [i for i in issues if i.get("severity") == "high"]
        if high_severity_issues:
            status = "changes_requested"
            confidence = 1.0
        elif issues:
            status = "changes_requested"
            confidence = 0.7
        else:
            status = "approved"
            confidence = 0.8

        result = {
            "status": status,
            "confidence": confidence,
            "summary": f"Rule-based review found {len(issues)} issues",
            "issues": issues
        }

        return json.dumps(result, indent=2)

    def _parse_analysis(self, analysis: str) -> ReviewResult:
        """Parse AI analysis response"""
        try:
            # Try to extract JSON from response
            json_match = re.search(r'\{[\s\S]*\}', analysis)
            if json_match:
                data = json.loads(json_match.group())

                status = ReviewStatus.APPROVED if data.get("status") == "approved" else ReviewStatus.CHANGES_REQUESTED
                confidence = float(data.get("confidence", 0.5))
                feedback = data.get("summary", "")
                issues = data.get("issues", [])

                return ReviewResult(
                    status=status,
                    confidence=confidence,
                    feedback=feedback,
                    issues=issues,
                    metadata={"raw_analysis": analysis}
                )
        except (json.JSONDecodeError, ValueError) as e:
            print(f"Warning: Failed to parse AI response: {e}")

        # Fallback
        return ReviewResult(
            status=ReviewStatus.CHANGES_REQUESTED,
            confidence=0.5,
            feedback="Failed to parse AI analysis",
            issues=[],
            metadata={"raw_analysis": analysis}
        )

    def should_auto_merge(self, result: ReviewResult) -> Tuple[bool, str]:
        """Determine if PR should be auto-merged based on review result"""
        mode = self.config.get("ai_reviewer", {}).get("mode", "manual")
        threshold = self.config.get("ai_reviewer", {}).get("auto_merge_threshold", 0.9)

        if mode == "manual":
            return False, "Manual mode: auto-merge disabled"

        if mode == "semi-auto":
            return False, "Semi-auto mode: requires admin approval"

        if mode == "auto":
            if result.status == ReviewStatus.APPROVED and result.confidence >= threshold:
                return True, f"Auto-merge: confidence {result.confidence} >= {threshold}"
            else:
                return False, f"Auto-merge blocked: status={result.status}, confidence={result.confidence}"

        return False, f"Unknown mode: {mode}"

    def format_review_comment(self, result: ReviewResult) -> str:
        """Format review result as a comment"""
        templates = self.config.get("ai_reviewer", {}).get("templates", {})

        if result.status == ReviewStatus.APPROVED:
            template = templates.get("approval", "✅ AI Review: PASSED (confidence: {confidence})")
            return template.format(confidence=result.confidence)

        elif result.status == ReviewStatus.CHANGES_REQUESTED:
            feedback = result.feedback or "No specific feedback"
            issues_text = "\n".join([f"- [{i.get('severity', 'medium').upper()}] {i.get('message', '')}" for i in result.issues])

            template = templates.get("request_changes", "⚠️ AI Review: NEEDS CHANGES\n\n{feedback}")
            comment = template.format(feedback=feedback)

            if issues_text:
                comment += f"\n\n**Issues found:**\n{issues_text}"

            return comment

        elif result.status == ReviewStatus.ERROR:
            template = templates.get("error", "❌ AI Review: ERROR\n\n{error}")
            return template.format(error=result.feedback)

        return "AI Review: Unknown status"


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="AI Reviewer - Automated Code Review")
    parser.add_argument("--diff", help="Diff file or string to review")
    parser.add_argument("--pr-url", help="PR/MR URL (future feature)")
    parser.add_argument("--config", help="Path to team.yaml config")
    parser.add_argument("--output", help="Output file for review result")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # Initialize reviewer
    reviewer = AIReviewer(config_path=Path(args.config) if args.config else None)

    # Get diff content
    if args.diff:
        diff_path = Path(args.diff)
        if diff_path.exists():
            with open(diff_path) as f:
                diff_content = f.read()
        else:
            diff_content = args.diff
    else:
        # Read from stdin
        diff_content = sys.stdin.read()

    # Perform review
    result = reviewer.review_diff(diff_content)

    # Format output
    if args.json:
        output = json.dumps({
            "status": result.status.value,
            "confidence": result.confidence,
            "feedback": result.feedback,
            "issues": result.issues,
            "metadata": result.metadata
        }, indent=2)
    else:
        output = reviewer.format_review_comment(result)

    # Write output
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Review written to {args.output}")
    else:
        print(output)

    # Exit code based on status
    if result.status == ReviewStatus.APPROVED:
        sys.exit(0)
    elif result.status == ReviewStatus.CHANGES_REQUESTED:
        sys.exit(1)
    else:
        sys.exit(2)


if __name__ == "__main__":
    main()
