#!/usr/bin/env python3
"""
End-to-End Test Script for All 8 Models
Purpose: Test completions through LiteLLM gateway for all Vertex AI models
Usage: python test-all-models.py [--gateway-url URL] [--auth-token TOKEN]
"""

import argparse
import json
import sys
import time
from typing import Dict, Any
import urllib.request
import urllib.error


# Model list from litellm-complete.yaml
MODELS = [
    {"name": "gemini-2.5-flash", "priority": "P1", "test_prompt": "Say 'Hello' in one word"},
    {"name": "gemini-2.5-pro", "priority": "P1", "test_prompt": "Say 'Hello' in one word"},
    {"name": "deepseek-r1", "priority": "P2", "test_prompt": "What is 2+2?"},
    {"name": "llama3-405b", "priority": "P2", "test_prompt": "Say 'Hello' in one word"},
    {"name": "codestral", "priority": "P2", "test_prompt": "Write a Python function that returns True"},
    {"name": "qwen3-coder-480b", "priority": "P3", "test_prompt": "def hello(): pass"},
    {"name": "qwen3-235b", "priority": "P3", "test_prompt": "Say 'Hello' in one word"},
    {"name": "gpt-oss-20b", "priority": "P3", "test_prompt": "Say 'Hello' in one word"},
]


def test_model(gateway_url: str, auth_token: str, model: Dict[str, Any]) -> Dict[str, Any]:
    """Test a single model with a completion request."""
    url = f"{gateway_url}/chat/completions"
    
    data = {  # type: ignore[var-annotated]
        "model": model["name"],
        "messages": [
            {"role": "user", "content": model["test_prompt"]}
        ],
        "max_tokens": 50
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {auth_token}"
    }
    
    start_time = time.time()
    
    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=30) as response:
            response_data = json.loads(response.read().decode('utf-8'))
            latency = time.time() - start_time
            
            return {
                "model": model["name"],
                "status": "success",
                "latency_ms": round(latency * 1000, 2),
                "response": response_data.get("choices", [{}])[0].get("message", {}).get("content", ""),
                "usage": response_data.get("usage", {})
            }
            
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return {
            "model": model["name"],
            "status": "error",
            "error": f"HTTP {e.code}: {error_body}"
        }
    except urllib.error.URLError as e:
        return {
            "model": model["name"],
            "status": "error",
            "error": f"Connection error: {str(e.reason)}"
        }
    except Exception as e:
        return {
            "model": model["name"],
            "status": "error",
            "error": str(e)
        }


def main():
    parser = argparse.ArgumentParser(
        description="Test all 8 Vertex AI models through LiteLLM gateway"
    )
    parser.add_argument(
        "--gateway-url",
        default="http://localhost:4000",
        help="LiteLLM gateway URL (default: http://localhost:4000)"
    )
    parser.add_argument(
        "--auth-token",
        help="Authentication token (defaults to LITELLM_MASTER_KEY env var)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON"
    )
    
    args = parser.parse_args()
    
    # Get auth token from args or environment
    import os
    auth_token = args.auth_token or os.environ.get("LITELLM_MASTER_KEY")
    
    if not auth_token:
        print("Error: Authentication token required", file=sys.stderr)
        print("Provide --auth-token or set LITELLM_MASTER_KEY", file=sys.stderr)
        sys.exit(1)
    
    if not args.json:
        print("=" * 70)
        print("End-to-End Model Testing")
        print("=" * 70)
        print()
        print(f"Gateway URL: {args.gateway_url}")
        print(f"Testing {len(MODELS)} models...")
        print()
    
    results: list[Dict[str, Any]] = []
    success_count = 0
    error_count = 0
    
    for i, model in enumerate(MODELS, 1):
        if not args.json:
            print(f"[{i}/{len(MODELS)}] Testing {model['name']}...", end=" ", flush=True)
        
        result = test_model(args.gateway_url, auth_token, model)
        results.append(result)  # type: ignore[arg-type]  # type: ignore[arg-type]
        
        if result["status"] == "success":
            success_count += 1
            if not args.json:
                print(f"✓ {result['latency_ms']}ms")
        else:
            error_count += 1
            if not args.json:
                print(f"✗ {result.get('error', 'Unknown error')}")
    
    if args.json:
        print(json.dumps({
            "gateway_url": args.gateway_url,
            "results": results,
            "summary": {
                "total": len(MODELS),
                "success": success_count,
                "errors": error_count
            }
        }, indent=2))
    else:
        print()
        print("=" * 70)
        print("Summary")
        print("=" * 70)
        print(f"Total models: {len(MODELS)}")
        print(f"Successful: {success_count}")
        print(f"Errors: {error_count}")
        print()
        
        if error_count > 0:
            print("⚠️  Some models failed. Check errors above.")
            print()
            print("Common fixes:")
            print("  1. Verify models are configured in litellm-complete.yaml")
            print("  2. Check YOUR_PROJECT_ID is replaced with actual project")
            print("  3. Ensure Google Cloud credentials are set up")
            print("  4. Verify models are available in your region")
        else:
            print("✓ All models working correctly!")
        
        print()
    
    sys.exit(0 if error_count == 0 else 1)


if __name__ == "__main__":
    main()
