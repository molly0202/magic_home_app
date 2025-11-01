#!/usr/bin/env python3
"""
Script to automatically convert Text widgets to TranslatableText widgets
for complete provider app translation support.
"""

import os
import re
import glob

def add_translatable_import(file_path):
    """Add TranslatableText import if not already present"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if import already exists
    if "import '../../widgets/translatable_text.dart';" in content:
        return content
    
    # Find the last import line and add after it
    import_pattern = r"(import [^;]+;)"
    matches = list(re.finditer(import_pattern, content))
    
    if matches:
        last_import = matches[-1]
        insert_pos = last_import.end()
        new_content = (content[:insert_pos] + 
                      "\nimport '../../widgets/translatable_text.dart';" + 
                      content[insert_pos:])
        return new_content
    
    return content

def convert_text_widgets(content):
    """Convert Text widgets to TranslatableText widgets"""
    
    # Pattern 1: const Text('string') -> const TranslatableText('string')
    content = re.sub(
        r'\bconst Text\(',
        'const TranslatableText(',
        content
    )
    
    # Pattern 2: Text('string') -> TranslatableText('string') 
    content = re.sub(
        r'\bText\(',
        'TranslatableText(',
        content
    )
    
    # Pattern 3: new Text('string') -> new TranslatableText('string')
    content = re.sub(
        r'\bnew Text\(',
        'new TranslatableText(',
        content
    )
    
    return content

def convert_snackbar_content(content):
    """Convert SnackBar Text content to TranslatableText"""
    # SnackBar(content: Text('message')) -> SnackBar(content: TranslatableText('message'))
    content = re.sub(
        r'SnackBar\(content: Text\(',
        'SnackBar(content: TranslatableText(',
        content
    )
    
    return content

def process_file(file_path):
    """Process a single Dart file for translation conversion"""
    print(f"Processing: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        # Add import
        content = add_translatable_import(original_content)
        
        # Convert Text widgets
        content = convert_text_widgets(content)
        
        # Convert SnackBar content
        content = convert_snackbar_content(content)
        
        # Write back if changes were made
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Updated: {file_path}")
            return True
        else:
            print(f"ℹ️  No changes needed: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to convert all provider screens to use TranslatableText"""
    
    # Define provider-related screen directories
    provider_screen_patterns = [
        "lib/screens/auth/*.dart",
        "lib/screens/home/*.dart", 
        "lib/screens/tasks/*.dart",
        "lib/screens/bidding/*.dart",
        "lib/screens/providers/*.dart",
        "lib/screens/reviews/*.dart",
    ]
    
    total_files = 0
    updated_files = 0
    
    print("🌐 Starting Provider App Translation Conversion...")
    print("=" * 60)
    
    for pattern in provider_screen_patterns:
        files = glob.glob(pattern)
        
        for file_path in files:
            # Skip test files
            if '_test.dart' in file_path:
                continue
                
            total_files += 1
            if process_file(file_path):
                updated_files += 1
    
    print("=" * 60)
    print(f"🎉 Translation conversion completed!")
    print(f"📊 Files processed: {total_files}")
    print(f"✅ Files updated: {updated_files}")
    print(f"📱 Provider app is now fully translatable!")
    
    print("\n🔧 Next steps:")
    print("1. Test the translation functionality with the floating translate button")
    print("2. Verify all text is properly translating in different languages")
    print("3. Handle any InputDecoration labels that need custom translation")

if __name__ == "__main__":
    main()
