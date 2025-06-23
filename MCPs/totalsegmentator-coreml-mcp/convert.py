#!/usr/bin/env python3
"""
Simple TotalSegmentator to CoreML Conversion Script
Run this to convert the model with default settings
"""

import os
import sys

# Check if we're in the right directory
if os.path.exists('scripts/convert_full_model.py'):
    # Run the full conversion script
    sys.exit(os.system('python scripts/convert_full_model.py'))
else:
    print("Error: Cannot find scripts/convert_full_model.py")
    print("Current directory:", os.getcwd())
    print("\nMake sure you're in the totalsegmentator-coreml-mcp directory")
    
    # Try to find the script
    for root, dirs, files in os.walk('.'):
        if 'convert_full_model.py' in files:
            print(f"\nFound script at: {os.path.join(root, 'convert_full_model.py')}")
            
    sys.exit(1)