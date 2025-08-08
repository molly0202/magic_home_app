#!/usr/bin/env python3
"""
Xcode 16.3 Framework Conflict Resolution Script
Manually fixes duplicate gRPC framework embedding in iOS builds
"""

import os
import re
import shutil
from pathlib import Path

def fix_framework_conflicts():
    """Main function to fix Xcode framework conflicts"""
    
    print("🔧 Starting Xcode 16.3 Framework Conflict Resolution...")
    
    project_root = Path(".")
    ios_dir = project_root / "ios"
    runner_project = ios_dir / "Runner.xcodeproj" / "project.pbxproj"
    
    if not runner_project.exists():
        print("❌ Error: Runner.xcodeproj/project.pbxproj not found")
        return False
    
    # Backup the original project file
    backup_file = runner_project.with_suffix('.pbxproj.backup')
    shutil.copy2(runner_project, backup_file)
    print(f"📋 Created backup: {backup_file}")
    
    # Read the project file
    with open(runner_project, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Track changes
    changes_made = 0
    
    # 1. Find and remove duplicate PBXBuildFile entries for gRPC frameworks
    print("🔍 Removing duplicate PBXBuildFile entries...")
    
    grpc_frameworks = [
        'grpc.framework',
        'grpcpp.framework', 
        'absl.framework',
        'openssl_grpc.framework',
        'FirebaseFirestoreInternal.framework',
        'BoringSSL-GRPC.framework'
    ]
    
    for framework in grpc_frameworks:
        # Find all PBXBuildFile entries for this framework
        pattern = r'([A-Z0-9]{24})\s*/\* ' + re.escape(framework) + r' in Embed Pods Frameworks \*/ = \{isa = PBXBuildFile; fileRef = ([A-Z0-9]{24})[^}]+\};'
        matches = re.findall(pattern, content)
        
        if len(matches) > 1:
            print(f"📝 Found {len(matches)} duplicate entries for {framework}")
            
            # Keep the first one, remove the rest
            for i, (build_file_id, file_ref_id) in enumerate(matches[1:], 1):
                # Remove the PBXBuildFile entry
                build_file_pattern = build_file_id + r'\s*/\* ' + re.escape(framework) + r' in Embed Pods Frameworks \*/ = \{isa = PBXBuildFile; fileRef = ' + file_ref_id + r'[^}]+\};'
                content = re.sub(build_file_pattern, '', content)
                
                # Remove references from PBXCopyFilesBuildPhase
                copy_phase_pattern = build_file_id + r'\s*/\* ' + re.escape(framework) + r' in Embed Pods Frameworks \*/[,\s]*'
                content = re.sub(copy_phase_pattern, '', content)
                
                changes_made += 1
                print(f"❌ Removed duplicate {i}: {framework}")
    
    # 2. Clean up empty lines and formatting
    print("🧹 Cleaning up project file formatting...")
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)  # Remove multiple empty lines
    content = re.sub(r',\s*\n\s*\)', '\n\t\t\t)', content)  # Fix trailing commas
    
    # 3. Write the modified content back
    with open(runner_project, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Applied {changes_made} fixes to project file")
    
    # 4. Create a script to run at build time for additional cleanup
    create_build_script()
    
    return changes_made > 0

def create_build_script():
    """Create a build-time script for additional framework cleanup"""
    
    script_path = Path("ios/framework_cleanup.sh")
    script_content = '''#!/bin/bash
# Runtime framework conflict resolution for Xcode 16.3
# This script runs during the build process to ensure no duplicate frameworks

echo "🔧 Runtime framework cleanup starting..."

FRAMEWORKS_DIR="$BUILT_PRODUCTS_DIR/$FRAMEWORKS_FOLDER_PATH"

if [ -d "$FRAMEWORKS_DIR" ]; then
    echo "📁 Checking frameworks in: $FRAMEWORKS_DIR"
    
    # List of problematic frameworks that often get duplicated
    PROBLEMATIC_FRAMEWORKS=(
        "grpc.framework"
        "grpcpp.framework" 
        "absl.framework"
        "openssl_grpc.framework"
        "FirebaseFirestoreInternal.framework"
        "BoringSSL-GRPC.framework"
    )
    
    for FRAMEWORK in "${PROBLEMATIC_FRAMEWORKS[@]}"; do
        FRAMEWORK_PATHS=($(find "$FRAMEWORKS_DIR" -name "$FRAMEWORK" 2>/dev/null))
        
        if [ ${#FRAMEWORK_PATHS[@]} -gt 1 ]; then
            echo "⚠️  Found ${#FRAMEWORK_PATHS[@]} copies of $FRAMEWORK"
            
            # Keep the first one, remove the rest
            for ((i=1; i<${#FRAMEWORK_PATHS[@]}; i++)); do
                echo "🗑️  Removing duplicate: ${FRAMEWORK_PATHS[i]}"
                rm -rf "${FRAMEWORK_PATHS[i]}"
            done
        fi
    done
    
    echo "✅ Framework cleanup completed"
else
    echo "ℹ️  Frameworks directory not found, skipping cleanup"
fi
'''
    
    with open(script_path, 'w') as f:
        f.write(script_content)
    
    # Make the script executable
    os.chmod(script_path, 0o755)
    print(f"📜 Created build script: {script_path}")

if __name__ == "__main__":
    success = fix_framework_conflicts()
    
    if success:
        print("\n🎉 Framework conflict resolution completed!")
        print("📋 Next steps:")
        print("   1. Try building your app again: flutter run -d [device-id]")
        print("   2. If issues persist, check the backup file and Xcode build logs")
        print("   3. The build script will provide additional cleanup during build")
    else:
        print("\n❌ No changes were needed or errors occurred")
        print("💡 The project file might already be clean or have a different structure")
