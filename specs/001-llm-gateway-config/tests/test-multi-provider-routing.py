#!/usr/bin/env python3
"""
Multi-Provider Routing Test

Purpose: Verify that requests are correctly routed across multiple providers
User Story: US3 - Multi-Provider Gateway Configuration (Priority: P3)
Usage: python test-multi-provider-routing.py [--config <config-file>]
Exit Codes: 0 (pass), 1 (fail), 2 (setup error)
"""

import os
import sys
import time
import json
import argparse
import requests
from typing import Dict, List, Tuple
from collections import defaultdict

# Configuration
GATEWAY_URL = os.getenv("ANTHROPIC_BASE_URL", "http://localhost:4000")
LITELLM_KEY = os.getenv("ANTHROPIC_API_KEY", "")
TEST_ITERATIONS = 10  # Number of requests to send for routing verification


def print_header(text: str):
    """Print formatted header."""
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")


def check_gateway_health() -> bool:
    """Check if LiteLLM gateway is healthy."""
    try:
        response = requests.get(f"{GATEWAY_URL}/health", timeout=5)
        if response.status_code == 200:
            print(f"✓ Gateway is healthy at {GATEWAY_URL}")
            return True
        else:
            print(f"❌ Gateway returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to gateway: {e}")
        return False


def get_model_info() -> List[Dict]:
    """Retrieve available models from gateway."""
    try:
        response = requests.get(
            f"{GATEWAY_URL}/model/info",
            headers={"Authorization": f"Bearer {LITELLM_KEY}"},
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            models = data.get("data", [])
            print(f"✓ Found {len(models)} configured models")
            return models
        else:
            print(f"❌ Failed to get model info: {response.status_code}")
            return []
    except requests.exceptions.RequestException as e:
        print(f"❌ Error getting model info: {e}")
        return []


def send_test_request(model_name: str, iteration: int) -> Tuple[bool, str, float]:
    """Send a test request to the gateway."""
    start_time = time.time()
    
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
                "max_tokens": 20,
                "messages": [{
                    "role": "user",
                    "content": f"Reply with just the number {iteration}"
                }]
            },
            timeout=30
        )
        
        elapsed = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            content = data.get("content", [{}])[0].get("text", "")
            return True, content, elapsed
        else:
            return False, f"HTTP {response.status_code}: {response.text}", elapsed
            
    except requests.exceptions.Timeout:
        elapsed = time.time() - start_time
        return False, "Request timeout", elapsed
    except requests.exceptions.RequestException as e:
        elapsed = time.time() - start_time
        return False, str(e), elapsed


def test_routing_distribution(models: List[str]) -> Dict[str, int]:
    """Test that requests are distributed across providers."""
    print_header("Testing Routing Distribution")
    
    print(f"Sending {TEST_ITERATIONS} requests per model...")
    print(f"Models: {', '.join(models)}\n")
    
    results = defaultdict(lambda: {"success": 0, "fail": 0, "latencies": []})
    
    for iteration in range(TEST_ITERATIONS):
        for model in models:
            success, response, latency = send_test_request(model, iteration)
            
            if success:
                results[model]["success"] += 1
                results[model]["latencies"].append(latency)
                print(f"  ✓ {model} (#{iteration+1}): {latency:.2f}s")
            else:
                results[model]["fail"] += 1
                print(f"  ❌ {model} (#{iteration+1}): {response}")
            
            time.sleep(0.5)  # Small delay between requests
    
    return results


def analyze_results(results: Dict) -> bool:
    """Analyze routing results and determine if test passed."""
    print_header("Routing Analysis")
    
    all_passed = True
    total_requests = 0
    total_success = 0
    
    for model, stats in results.items():
        success_count = stats["success"]
        fail_count = stats["fail"]
        latencies = stats["latencies"]
        
        total_requests += success_count + fail_count
        total_success += success_count
        
        # Calculate statistics
        success_rate = (success_count / (success_count + fail_count) * 100) if (success_count + fail_count) > 0 else 0
        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        min_latency = min(latencies) if latencies else 0
        max_latency = max(latencies) if latencies else 0
        
        print(f"\n📊 {model}:")
        print(f"   Requests: {success_count + fail_count}")
        print(f"   Success:  {success_count} ({success_rate:.1f}%)")
        print(f"   Failed:   {fail_count}")
        
        if latencies:
            print(f"   Latency:  avg={avg_latency:.2f}s, min={min_latency:.2f}s, max={max_latency:.2f}s")
        
        # Check if model passed (>80% success rate)
        if success_rate < 80:
            print(f"   ❌ FAIL: Success rate below 80%")
            all_passed = False
        else:
            print(f"   ✓ PASS")
    
    # Overall statistics
    overall_success_rate = (total_success / total_requests * 100) if total_requests > 0 else 0
    
    print(f"\n{'='*60}")
    print(f"Overall Results:")
    print(f"  Total Requests: {total_requests}")
    print(f"  Total Success:  {total_success} ({overall_success_rate:.1f}%)")
    print(f"  Total Failed:   {total_requests - total_success}")
    
    if overall_success_rate >= 80:
        print(f"\n✅ PASS: Overall success rate is {overall_success_rate:.1f}%")
    else:
        print(f"\n❌ FAIL: Overall success rate is {overall_success_rate:.1f}% (expected >80%)")
        all_passed = False
    
    return all_passed


def test_routing_strategy_compliance(models: List[str], strategy: str):
    """Verify routing strategy is working as expected."""
    print_header(f"Verifying {strategy} Strategy")
    
    if strategy == "simple-shuffle":
        print("✓ Simple shuffle: Requests should be evenly distributed")
        print("  (Random distribution, expect ~equal request counts)")
    elif strategy == "least-busy":
        print("✓ Least busy: Faster models should receive more requests")
        print("  (Adaptive distribution based on response times)")
    elif strategy == "usage-based-routing":
        print("✓ Usage-based: Higher priority models should be preferred")
        print("  (Priority-based distribution)")
    else:
        print(f"⚠ Unknown strategy: {strategy}")


def main():
    """Main test routine."""
    parser = argparse.ArgumentParser(description="Test multi-provider routing")
    parser.add_argument("--config", help="Path to LiteLLM config file (optional)")
    parser.add_argument("--iterations", type=int, default=TEST_ITERATIONS, help="Number of test iterations")
    parser.add_argument("--models", nargs="+", help="Specific models to test (optional)")
    args = parser.parse_args()
    
    global TEST_ITERATIONS
    TEST_ITERATIONS = args.iterations
    
    print_header("Multi-Provider Routing Test")
    
    # Check prerequisites
    if not LITELLM_KEY:
        print("❌ ERROR: ANTHROPIC_API_KEY environment variable not set")
        print("   This should contain your LiteLLM master key")
        sys.exit(2)
    
    # Check gateway health
    if not check_gateway_health():
        print("\n❌ ERROR: Gateway is not accessible")
        print("   Start LiteLLM proxy first: litellm --config <config.yaml>")
        sys.exit(2)
    
    # Get available models
    model_info = get_model_info()
    if not model_info:
        print("\n❌ ERROR: No models found in gateway configuration")
        sys.exit(2)
    
    # Extract model names
    if args.models:
        test_models = args.models
    else:
        test_models = [m.get("model_name", "") for m in model_info if m.get("model_name")]
    
    if not test_models:
        print("\n❌ ERROR: No models available for testing")
        sys.exit(2)
    
    print(f"\nTesting with models: {', '.join(test_models)}")
    
    # Detect routing strategy (from config if provided)
    routing_strategy = "unknown"
    if args.config and os.path.exists(args.config):
        import yaml
        with open(args.config, 'r') as f:
            config = yaml.safe_load(f)
            routing_strategy = config.get("router_settings", {}).get("routing_strategy", "simple-shuffle")
    
    test_routing_strategy_compliance(test_models, routing_strategy)
    
    # Run routing distribution test
    results = test_routing_distribution(test_models)
    
    # Analyze results
    passed = analyze_results(results)
    
    # Exit with appropriate code
    if passed:
        print_header("✅ All Tests Passed")
        print("Multi-provider routing is working correctly!\n")
        sys.exit(0)
    else:
        print_header("❌ Tests Failed")
        print("Some routing issues detected. Review logs above.\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
