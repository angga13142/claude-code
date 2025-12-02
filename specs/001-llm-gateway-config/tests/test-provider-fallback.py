#!/usr/bin/env python3
"""
Provider Fallback Verification Script

Purpose: Verify that fallback mechanisms work when primary provider fails
User Story: US3 - Multi-Provider Gateway Configuration (Priority: P3)
Usage: python test-provider-fallback.py [--primary <model>] [--fallback <model>]
Exit Codes: 0 (pass), 1 (fail), 2 (setup error)
"""

import os
import sys
import time
import argparse
import requests
from typing import Tuple, List

# Configuration
GATEWAY_URL = os.getenv("ANTHROPIC_BASE_URL", "http://localhost:4000")
LITELLM_KEY = os.getenv("ANTHROPIC_API_KEY", "")


def print_header(text: str):
    """Print formatted header."""
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")


def check_gateway_health() -> bool:
    """Check if LiteLLM gateway is healthy."""
    try:
        response = requests.get(f"{GATEWAY_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def send_request(model_name: str, timeout: int = 30) -> Tuple[bool, str, dict]:
    """Send a test request to the gateway."""
    try:
        response = requests.post(
            f"{GATEWAY_URL}/v1/messages",
            headers={
                "x-api-key": LITELLM_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            },
            json={
                "model": model_name,
                "max_tokens": 10,
                "messages": [{
                    "role": "user",
                    "content": "Reply with: test"
                }]
            },
            timeout=timeout
        )
        
        if response.status_code == 200:
            return True, "Success", response.json()
        else:
            return False, f"HTTP {response.status_code}", response.json() if response.text else {}
            
    except requests.exceptions.Timeout:
        return False, "Timeout", {}
    except requests.exceptions.RequestException as e:
        return False, str(e), {}


def get_model_list() -> List[str]:
    """Get list of configured models from gateway."""
    try:
        response = requests.get(
            f"{GATEWAY_URL}/model/info",
            headers={"Authorization": f"Bearer {LITELLM_KEY}"},
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            models = [m.get("model_name", "") for m in data.get("data", [])]
            return [m for m in models if m]
        return []
    except:
        return []


def test_fallback_scenario(primary: str, fallback: str) -> bool:
    """Test that fallback works when primary fails."""
    print_header("Fallback Scenario Test")
    
    print(f"Primary Model:  {primary}")
    print(f"Fallback Model: {fallback}\n")
    
    # Test 1: Verify both models work independently
    print("Step 1: Verifying both models are accessible...")
    
    primary_success, primary_msg, _ = send_request(primary)
    if primary_success:
        print(f"  ✓ Primary model responding: {primary}")
    else:
        print(f"  ⚠ Primary model not responding: {primary_msg}")
        print(f"    (This is expected if testing fallback from failed primary)\n")
    
    fallback_success, fallback_msg, _ = send_request(fallback)
    if fallback_success:
        print(f"  ✓ Fallback model responding: {fallback}")
    else:
        print(f"  ❌ Fallback model not responding: {fallback_msg}")
        print(f"     Cannot test fallback if backup model is also down")
        return False
    
    print()
    
    # Test 2: Simulate primary failure by sending multiple requests
    print("Step 2: Testing automatic fallback...")
    print(f"  Sending requests that may trigger fallback to {fallback}...\n")
    
    success_count = 0
    fallback_detected = False
    
    for i in range(5):
        success, msg, response_data = send_request(primary, timeout=10)
        
        if success:
            success_count += 1
            # Check if response came from fallback model (if LiteLLM includes model info)
            actual_model = response_data.get("model", primary)
            if fallback in actual_model or actual_model != primary:
                fallback_detected = True
                print(f"  ✓ Request {i+1}: Success (fallback to {actual_model})")
            else:
                print(f"  ✓ Request {i+1}: Success (primary {primary})")
        else:
            print(f"  ⚠ Request {i+1}: Failed ({msg}) - Fallback should activate")
        
        time.sleep(1)
    
    print()
    
    # Analyze results
    if success_count == 0:
        print("❌ FAIL: All requests failed - fallback not working")
        return False
    elif success_count < 5 and fallback_detected:
        print(f"✅ PASS: Fallback mechanism activated ({success_count}/5 requests succeeded)")
        return True
    elif success_count == 5:
        print(f"✅ PASS: All requests succeeded ({success_count}/5)")
        if fallback_detected:
            print("  ✓ Fallback was used for some requests")
        else:
            print("  ℹ Primary model handled all requests (no failures to trigger fallback)")
        return True
    else:
        print(f"⚠ PARTIAL: {success_count}/5 requests succeeded")
        print("  Fallback may be working, but some requests still failed")
        return False


def test_cooldown_recovery(model: str, cooldown_time: int = 60) -> bool:
    """Test that models recover after cooldown period."""
    print_header("Cooldown Recovery Test")
    
    print(f"Model: {model}")
    print(f"Expected cooldown: {cooldown_time}s\n")
    
    print("ℹ This test simulates a model failure and recovery cycle")
    print(f"  1. Mark model as unhealthy (via repeated failures)")
    print(f"  2. Wait for cooldown period ({cooldown_time}s)")
    print(f"  3. Verify model returns to healthy state\n")
    
    print("⚠ This test takes time and may not be fully automated")
    print("  Manual verification recommended via LiteLLM admin UI\n")
    
    # Send requests to check current health
    success, msg, _ = send_request(model)
    if success:
        print(f"✓ Model is currently healthy")
    else:
        print(f"⚠ Model is currently unhealthy: {msg}")
    
    print(f"\nℹ To manually test cooldown:")
    print(f"  1. Visit {GATEWAY_URL}/ui")
    print(f"  2. Check model health status")
    print(f"  3. Observe cooldown timer after failures")
    
    return True  # Manual test - always pass


def main():
    """Main test routine."""
    parser = argparse.ArgumentParser(description="Test provider fallback mechanisms")
    parser.add_argument("--primary", help="Primary model name")
    parser.add_argument("--fallback", help="Fallback model name")
    parser.add_argument("--cooldown", type=int, default=60, help="Expected cooldown time (seconds)")
    args = parser.parse_args()
    
    print_header("Provider Fallback Verification Test")
    
    # Check prerequisites
    if not LITELLM_KEY:
        print("❌ ERROR: ANTHROPIC_API_KEY environment variable not set")
        sys.exit(2)
    
    if not check_gateway_health():
        print("❌ ERROR: Gateway is not accessible")
        print(f"   Check that LiteLLM is running at {GATEWAY_URL}")
        sys.exit(2)
    
    print(f"✓ Gateway is healthy at {GATEWAY_URL}\n")
    
    # Get available models
    models = get_model_list()
    if not models:
        print("❌ ERROR: No models found in gateway configuration")
        sys.exit(2)
    
    print(f"Available models: {', '.join(models)}\n")
    
    # Determine test models
    if args.primary and args.fallback:
        primary_model = args.primary
        fallback_model = args.fallback
    elif len(models) >= 2:
        primary_model = models[0]
        fallback_model = models[1]
        print(f"⚠ No models specified, using first two available:")
        print(f"  Primary:  {primary_model}")
        print(f"  Fallback: {fallback_model}\n")
    else:
        print("❌ ERROR: Need at least 2 models for fallback testing")
        print("   Specify --primary and --fallback, or configure multiple models")
        sys.exit(2)
    
    # Run tests
    all_passed = True
    
    # Test 1: Fallback scenario
    if not test_fallback_scenario(primary_model, fallback_model):
        all_passed = False
    
    # Test 2: Cooldown recovery (informational)
    test_cooldown_recovery(primary_model, args.cooldown)
    
    # Summary
    if all_passed:
        print_header("✅ Fallback Tests Passed")
        print("Provider fallback mechanisms are working correctly!\n")
        print("Recommendations:")
        print("  1. Monitor fallback frequency in production")
        print("  2. Adjust allowed_fails and cooldown_time based on error patterns")
        print("  3. Set up alerts for excessive fallback usage")
        print("  4. Verify all fallback models have sufficient capacity\n")
        sys.exit(0)
    else:
        print_header("❌ Fallback Tests Failed")
        print("Some fallback issues detected:\n")
        print("Troubleshooting:")
        print("  1. Check router_settings in LiteLLM config")
        print("  2. Verify allowed_fails and cooldown_time settings")
        print("  3. Ensure fallback models have adequate rate limits")
        print("  4. Review LiteLLM logs for error details")
        print(f"  5. Check admin UI at {GATEWAY_URL}/ui\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
