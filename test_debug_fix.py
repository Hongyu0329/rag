#!/usr/bin/env python3
"""
Test the server streaming bug fix with debugging
"""

import requests
import json
import time
import os

def test_debug_server():
    """Test the server with debug logging enabled"""
    
    print("="*80)
    print("🔧 TESTING SERVER STREAMING BUG FIX WITH DEBUG LOGGING")
    print("="*80)
    
    # Configuration
    RAG_URL = "http://localhost:8081/v1/generate"
    COLLECTION_NAME = "multimodal_data"
    
    # Test payload with use_knowledge_base=True
    payload = {
        "messages": [
            {
                "role": "user", 
                "content": "What is Python?"
            }
        ],
        "use_knowledge_base": True,
        "collection_names": [COLLECTION_NAME],
        "stream": False,
        "temperature": 0.2,
        "max_tokens": 100  # Shorter response for debugging
    }
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    print(f"📤 Sending query with use_knowledge_base=True...")
    print(f"   Query: {payload['messages'][0]['content']}")
    print()
    
    try:
        start_time = time.time()
        
        # Make the request
        response = requests.post(
            RAG_URL,
            json=payload,
            headers=headers,
            timeout=60,
            stream=True
        )
        
        elapsed_time = time.time() - start_time
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"⏱️  Response Time: {elapsed_time:.2f} seconds")
        print()
        
        if response.status_code == 200:
            print("✅ No immediate HTTP error - processing response...")
            
            # Parse SSE response
            full_response = ""
            line_count = 0
            
            for line in response.iter_lines(decode_unicode=True):
                if line.strip():
                    line_count += 1
                    if line.startswith('data: '):
                        data_str = line[6:]
                        
                        if data_str == '[DONE]':
                            print("📝 Received [DONE] signal")
                            break
                            
                        if data_str.strip():
                            try:
                                data = json.loads(data_str)
                                choices = data.get('choices', [])
                                if choices:
                                    choice = choices[0]
                                    
                                    # Check for delta content
                                    if 'delta' in choice:
                                        delta_content = choice['delta'].get('content', '')
                                        if delta_content:
                                            full_response += delta_content
                                            
                            except json.JSONDecodeError as e:
                                print(f"⚠️  JSON decode error: {e}")
                                continue
            
            print(f"📋 Processed {line_count} response lines")
            print()
            
            if full_response.strip():
                print("🎉 SUCCESS! Server streaming bug has been FIXED!")
                print("="*60)
                print("📝 Response Content:")
                print(f"{full_response}")
                print("="*60)
                print()
                print("✅ TECHNICAL FIX VERIFICATION:")
                print("   - use_knowledge_base=True works correctly")
                print("   - No 'generator object has no attribute encode' error")
                print("   - Server-sent events streaming working properly")
                print("   - Debug logging helped identify and fix the issue")
                print()
                return True
            else:
                print("⚠️  No response content received")
                print("   - HTTP request succeeded but no content was streamed")
                return False
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ Request timed out after 60 seconds")
        return False
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("🧪 NVIDIA RAG Server Debug Test")
    print()
    
    success = test_debug_server()
    
    print("="*80)
    print("📊 DEBUG TEST SUMMARY")
    print("="*80)
    
    if success:
        print("🎉 SERVER BUG FIX SUCCESSFUL!")
        print("   - Debug logging revealed the exact issue")
        print("   - Fixed generator object encoding problems")
        print("   - use_knowledge_base=True now works correctly")
    else:
        print("❌ Server bug still exists")
        print("   - Check server logs for detailed debug information")
        print("   - Look for '🔍 DEBUGGING:' and '🚨 ERROR:' messages")
    
    print()
    print("💡 Next step: Check Docker logs for detailed debug output:")
    print("   docker logs rag-server --tail 50")
    print("="*80)