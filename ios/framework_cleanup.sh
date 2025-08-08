#!/bin/bash
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
