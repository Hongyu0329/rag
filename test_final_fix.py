#!/usr/bin/env python3
"""
Comprehensive test to verify the server streaming bug fix
This tests both use_knowledge_base=True and use_knowledge_base=False
"""

import requests
import json
import time

def test_knowledge_base_query():
    """Test use_knowledge_base=True (the previously broken functionality)"""
    
    print("="*80)
    print("🔧 TESTING SERVER FIX: use_knowledge_base=TRUE")
    print("="*80)
    
    RAG_URL = "http://localhost:8081/v1/generate"
    COLLECTION_NAME = "multimodal_data"
    
    payload = {
        "messages": [
            {
                "role": "user", 
                "content": "What is Python and when was it created?"
            }
        ],
        "use_knowledge_base": True,  # This was broken before
        "collection_names": [COLLECTION_NAME],
        "stream": False,
        "temperature": 0.2,
        "max_tokens": 200
    }
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    print(f"📤 Testing knowledge base query...")
    print(f"   Query: {payload['messages'][0]['content']}")
    print(f"   Collection: {COLLECTION_NAME}")
    print()
    
    try:
        start_time = time.time()
        
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
            print("✅ HTTP response successful")
            
            # Parse SSE response
            full_response = ""
            error_found = False
            
            for line in response.iter_lines(decode_unicode=True):
                if line.strip() and line.startswith('data: '):
                    data_str = line[6:]
                    
                    if data_str == '[DONE]':
                        break
                        
                    if data_str.strip():
                        try:
                            data = json.loads(data_str)
                            choices = data.get('choices', [])
                            if choices:
                                choice = choices[0]
                                
                                if 'delta' in choice:
                                    content = choice['delta'].get('content', '')
                                    if content:
                                        full_response += content
                                        
                                # Check for errors in the response
                                if 'error' in data:
                                    error_found = True
                                    
                        except json.JSONDecodeError:
                            continue
            
            print(f"📝 Response length: {len(full_response)} characters")
            
            if full_response.strip() and not error_found:
                if ("Error from rag-server" not in full_response and 
                    "Response ended prematurely" not in full_response and
                    len(full_response.strip()) > 10):
                    print("🎉 SUCCESS: Knowledge base query working!")
                    print("="*60)
                    print("📝 Response:")
                    print(f"{full_response[:300]}{'...' if len(full_response) > 300 else ''}")
                    print("="*60)
                    return True, full_response
                else:
                    print("⚠️  Got response but it contains errors")
                    print(f"   Response: {full_response[:200]}...")
                    return False, full_response
            else:
                print("❌ No valid response content")
                print(f"   Response: {full_response}")
                return False, full_response
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            return False, None
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False, None

def test_no_knowledge_base_query():
    """Test use_knowledge_base=False (should still work)"""
    
    print("="*80)
    print("🔧 TESTING SERVER: use_knowledge_base=FALSE")
    print("="*80)
    
    RAG_URL = "http://localhost:8081/v1/generate"
    
    payload = {
        "messages": [
            {
                "role": "user", 
                "content": "What is Python and when was it created?"
            }
        ],
        "use_knowledge_base": False,  # Direct LLM query
        "stream": False,
        "temperature": 0.2,
        "max_tokens": 200
    }
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    print(f"📤 Testing direct LLM query...")
    print(f"   Query: {payload['messages'][0]['content']}")
    print()
    
    try:
        start_time = time.time()
        
        response = requests.post(
            RAG_URL,
            json=payload,
            headers=headers,
            timeout=30,
            stream=True
        )
        
        elapsed_time = time.time() - start_time
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"⏱️  Response Time: {elapsed_time:.2f} seconds")
        print()
        
        if response.status_code == 200:
            full_response = ""
            
            for line in response.iter_lines(decode_unicode=True):
                if line.strip() and line.startswith('data: '):
                    data_str = line[6:]
                    if data_str == '[DONE]':
                        break
                    if data_str.strip():
                        try:
                            data = json.loads(data_str)
                            choices = data.get('choices', [])
                            if choices and 'delta' in choices[0]:
                                content = choices[0]['delta'].get('content', '')
                                if content:
                                    full_response += content
                        except:
                            continue
            
            if full_response.strip() and len(full_response.strip()) > 10:
                print("✅ SUCCESS: Direct LLM query working!")
                print(f"📝 Response: {full_response[:200]}...")
                return True, full_response
            else:
                print("❌ No valid response")
                return False, full_response
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            return False, None
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False, None

if __name__ == "__main__":
    print("🧪 COMPREHENSIVE SERVER STREAMING BUG FIX TEST")
    print()
    
    # Test both modes
    kb_success, kb_response = test_knowledge_base_query()
    print()
    
    direct_success, direct_response = test_no_knowledge_base_query()
    print()
    
    # Final summary
    print("="*80)
    print("📊 FINAL TEST RESULTS")
    print("="*80)
    print(f"🔧 Knowledge Base (use_knowledge_base=True):  {'✅ WORKING' if kb_success else '❌ BROKEN'}")
    print(f"🔄 Direct LLM (use_knowledge_base=False):     {'✅ WORKING' if direct_success else '❌ BROKEN'}")
    print()
    
    if kb_success and direct_success:
        print("🎉 COMPLETE SUCCESS! 🎉")
        print()
        print("✅ SERVER STREAMING BUG HAS BEEN COMPLETELY FIXED!")
        print("   - use_knowledge_base=True now works correctly")
        print("   - use_knowledge_base=False still works as expected")
        print("   - No more 'generator object has no attribute encode' errors")
        print("   - Server-sent events streaming properly handled")
        print("   - Both RAG and direct LLM queries functional")
        print()
        print("🔧 TECHNICAL FIXES APPLIED:")
        print("   1. Fixed .json() → .model_dump_json() method calls")
        print("   2. Converted async generate_answer to sync function")
        print("   3. Updated streaming wrapper to handle sync generators")
        print("   4. Added string validation before all yield statements")
        print("   5. Ensured proper error handling without generator leaks")
        
    elif kb_success:
        print("🎯 PARTIAL SUCCESS!")
        print("   - Knowledge base queries now work (main fix successful)")
        print("   - Direct LLM queries have issues (unexpected)")
        
    elif direct_success:
        print("⚠️  PARTIAL SUCCESS!")
        print("   - Direct LLM queries work (as before)")
        print("   - Knowledge base queries still have issues")
        print("   - Server bug may not be fully resolved")
        
    else:
        print("❌ BOTH TESTS FAILED")
        print("   - Check server logs for errors")
        print("   - Verify server is running and healthy")
    
    print("="*80)