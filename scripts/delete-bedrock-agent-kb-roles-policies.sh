#!/bin/bash

# Script to delete Bedrock KB cross-account roles and policies
# Usage: ./delete-bedrock-agent-kb-roles-policies.sh --agent-profile <profile> --agent-kb-profile <profile> [options]

# Don't use set -e to allow proper error handling
set -o pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [Required Parameters]"
    echo ""
    echo "Required Parameters:"
    echo "  --agent-profile <profile>         AWS CLI profile for agent account"
    echo "  --agent-kb-profile <profile>      AWS CLI profile for agent-kb account"
    echo "  --lambda-role <name>              Name of Lambda execution role to delete"
    echo "  --kb-access-role <name>           Name of KB access role to delete"
    echo "  --kb-access-policy <name>         Name of KB access policy to delete"
    echo "  --lambda-policy <name>            Name of Lambda policy to delete"
    echo "  --agent-account <number>          AWS account number for agent account"
    echo "  --agent-kb-account <number>       AWS account number for agent-kb account"
    echo "  --help                            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --agent-profile agent \\"
    echo "     --agent-kb-profile agent-kb \\"
    echo "     --lambda-role lambda_bedrock_kb_query_role \\"
    echo "     --kb-access-role bedrock_kb_access_role \\"
    echo "     --kb-access-policy bedrock_kb_access_policy \\"
    echo "     --lambda-policy lambda_bedrock_kb_query_policy \\"
    echo "     --agent-account 000000000000 \\"
    echo "     --agent-kb-account 999999999999"
    echo ""
    echo "⚠️  WARNING: This will permanently delete IAM roles and policies!"
    echo "    Make sure no other resources are using these roles before proceeding."
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --agent-profile)
            AGENT_PROFILE="$2"
            shift 2
            ;;
        --agent-kb-profile)
            AGENT_KB_PROFILE="$2"
            shift 2
            ;;
        --lambda-role)
            LAMBDA_ROLE_NAME="$2"
            shift 2
            ;;
        --kb-access-role)
            KB_ACCESS_ROLE_NAME="$2"
            shift 2
            ;;
        --kb-access-policy)
            KB_ACCESS_POLICY_NAME="$2"
            shift 2
            ;;
        --lambda-policy)
            LAMBDA_POLICY_NAME="$2"
            shift 2
            ;;
        --agent-account)
            AGENT_ACCOUNT_NUMBER="$2"
            shift 2
            ;;
        --agent-kb-account)
            AGENT_KB_ACCOUNT_NUMBER="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown parameter $1"
            usage
            ;;
    esac
done

# Validate all required parameters
MISSING_PARAMS=()

if [[ -z "$AGENT_PROFILE" ]]; then
    MISSING_PARAMS+=("--agent-profile")
fi

if [[ -z "$AGENT_KB_PROFILE" ]]; then
    MISSING_PARAMS+=("--agent-kb-profile")
fi

if [[ -z "$LAMBDA_ROLE_NAME" ]]; then
    MISSING_PARAMS+=("--lambda-role")
fi

if [[ -z "$KB_ACCESS_ROLE_NAME" ]]; then
    MISSING_PARAMS+=("--kb-access-role")
fi

if [[ -z "$KB_ACCESS_POLICY_NAME" ]]; then
    MISSING_PARAMS+=("--kb-access-policy")
fi

if [[ -z "$LAMBDA_POLICY_NAME" ]]; then
    MISSING_PARAMS+=("--lambda-policy")
fi

if [[ -z "$AGENT_ACCOUNT_NUMBER" ]]; then
    MISSING_PARAMS+=("--agent-account")
fi

if [[ -z "$AGENT_KB_ACCOUNT_NUMBER" ]]; then
    MISSING_PARAMS+=("--agent-kb-account")
fi

# Check if any parameters are missing
if [[ ${#MISSING_PARAMS[@]} -gt 0 ]]; then
    echo "Error: Missing required parameters:"
    for param in "${MISSING_PARAMS[@]}"; do
        echo "  $param"
    done
    echo ""
    usage
fi

# Validate account numbers format
if [[ ! "$AGENT_ACCOUNT_NUMBER" =~ ^[0-9]{12}$ ]]; then
    echo "Error: --agent-account must be a 12-digit AWS account number"
    exit 1
fi

if [[ ! "$AGENT_KB_ACCOUNT_NUMBER" =~ ^[0-9]{12}$ ]]; then
    echo "Error: --agent-kb-account must be a 12-digit AWS account number"
    exit 1
fi

echo "=========================================="
echo "Deleting Bedrock KB Cross-Account Roles"
echo "=========================================="
echo "Agent Profile: $AGENT_PROFILE"
echo "Agent-KB Profile: $AGENT_KB_PROFILE"
echo "Lambda Role: $LAMBDA_ROLE_NAME"
echo "KB Access Role: $KB_ACCESS_ROLE_NAME"
echo "KB Access Policy: $KB_ACCESS_POLICY_NAME"
echo "Lambda Policy: $LAMBDA_POLICY_NAME"
echo "Agent Account: $AGENT_ACCOUNT_NUMBER"
echo "Agent-KB Account: $AGENT_KB_ACCOUNT_NUMBER"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will permanently delete the following resources:"
echo "   - Lambda execution role and policy in agent account"
echo "   - KB access role and policy in agent-kb account"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "Starting deletion process..."

# Validate AWS CLI profiles before proceeding
echo "Validating AWS CLI profiles..."

# Check agent profile
echo "Checking agent profile: $AGENT_PROFILE"
AGENT_IDENTITY=$(aws sts get-caller-identity --profile "$AGENT_PROFILE" 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Failed to validate agent profile '$AGENT_PROFILE'. Error:"
    echo "$AGENT_IDENTITY"
    exit 1
fi

AGENT_ACTUAL_ACCOUNT=$(echo "$AGENT_IDENTITY" | jq -r '.Account' 2>/dev/null)
if [[ "$AGENT_ACTUAL_ACCOUNT" != "$AGENT_ACCOUNT_NUMBER" ]]; then
    echo "❌ Agent profile account mismatch!"
    echo "Expected: $AGENT_ACCOUNT_NUMBER"
    echo "Actual:   $AGENT_ACTUAL_ACCOUNT"
    exit 1
fi
echo "✓ Agent profile validated: $AGENT_ACTUAL_ACCOUNT"

# Check agent-kb profile
echo "Checking agent-kb profile: $AGENT_KB_PROFILE"
AGENT_KB_IDENTITY=$(aws sts get-caller-identity --profile "$AGENT_KB_PROFILE" 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Failed to validate agent-kb profile '$AGENT_KB_PROFILE'. Error:"
    echo "$AGENT_KB_IDENTITY"
    exit 1
fi

AGENT_KB_ACTUAL_ACCOUNT=$(echo "$AGENT_KB_IDENTITY" | jq -r '.Account' 2>/dev/null)
if [[ "$AGENT_KB_ACTUAL_ACCOUNT" != "$AGENT_KB_ACCOUNT_NUMBER" ]]; then
    echo "❌ Agent-KB profile account mismatch!"
    echo "Expected: $AGENT_KB_ACCOUNT_NUMBER"
    echo "Actual:   $AGENT_KB_ACTUAL_ACCOUNT"
    exit 1
fi
echo "✓ Agent-KB profile validated: $AGENT_KB_ACTUAL_ACCOUNT"

echo "✓ All profiles validated successfully!"
echo ""

# Step 1: Detach policies from Lambda role in agent account
echo "Step 1: Detaching policies from Lambda role in agent account..."

# Detach Lambda policy
echo "Detaching Lambda policy from Lambda role..."
aws iam detach-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-arn "arn:aws:iam::${AGENT_ACCOUNT_NUMBER}:policy/${LAMBDA_POLICY_NAME}" \
  --profile "$AGENT_PROFILE" 2>/dev/null || echo "⚠️  Lambda policy may not be attached or may not exist"

# Detach AWS managed policy
echo "Detaching AWSLambdaBasicExecutionRole from Lambda role..."
aws iam detach-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --profile "$AGENT_PROFILE" 2>/dev/null || echo "⚠️  AWSLambdaBasicExecutionRole may not be attached"

echo "✓ Policies detached from Lambda role"

# Step 2: Detach policy from KB access role in agent-kb account
echo "Step 2: Detaching policy from KB access role in agent-kb account..."

echo "Detaching KB access policy from KB access role..."
aws iam detach-role-policy \
  --role-name "$KB_ACCESS_ROLE_NAME" \
  --policy-arn "arn:aws:iam::${AGENT_KB_ACCOUNT_NUMBER}:policy/${KB_ACCESS_POLICY_NAME}" \
  --profile "$AGENT_KB_PROFILE" 2>/dev/null || echo "⚠️  KB access policy may not be attached or may not exist"

echo "✓ Policy detached from KB access role"

# Step 3: Delete Lambda policy in agent account
echo "Step 3: Deleting Lambda policy in agent account..."

LAMBDA_POLICY_ARN="arn:aws:iam::${AGENT_ACCOUNT_NUMBER}:policy/${LAMBDA_POLICY_NAME}"
if aws iam get-policy --policy-arn "$LAMBDA_POLICY_ARN" --profile "$AGENT_PROFILE" >/dev/null 2>&1; then
    aws iam delete-policy \
      --policy-arn "$LAMBDA_POLICY_ARN" \
      --profile "$AGENT_PROFILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Lambda policy deleted: $LAMBDA_POLICY_ARN"
    else
        echo "❌ Failed to delete Lambda policy: $LAMBDA_POLICY_ARN"
    fi
else
    echo "⚠️  Lambda policy does not exist: $LAMBDA_POLICY_ARN"
fi

# Step 4: Delete KB access policy in agent-kb account
echo "Step 4: Deleting KB access policy in agent-kb account..."

KB_ACCESS_POLICY_ARN="arn:aws:iam::${AGENT_KB_ACCOUNT_NUMBER}:policy/${KB_ACCESS_POLICY_NAME}"
if aws iam get-policy --policy-arn "$KB_ACCESS_POLICY_ARN" --profile "$AGENT_KB_PROFILE" >/dev/null 2>&1; then
    aws iam delete-policy \
      --policy-arn "$KB_ACCESS_POLICY_ARN" \
      --profile "$AGENT_KB_PROFILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ KB access policy deleted: $KB_ACCESS_POLICY_ARN"
    else
        echo "❌ Failed to delete KB access policy: $KB_ACCESS_POLICY_ARN"
    fi
else
    echo "⚠️  KB access policy does not exist: $KB_ACCESS_POLICY_ARN"
fi

# Step 5: Delete Lambda role in agent account
echo "Step 5: Deleting Lambda role in agent account..."

if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --profile "$AGENT_PROFILE" >/dev/null 2>&1; then
    aws iam delete-role \
      --role-name "$LAMBDA_ROLE_NAME" \
      --profile "$AGENT_PROFILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Lambda role deleted: $LAMBDA_ROLE_NAME"
    else
        echo "❌ Failed to delete Lambda role: $LAMBDA_ROLE_NAME"
        echo "   This may be because the role is still attached to other policies or resources."
    fi
else
    echo "⚠️  Lambda role does not exist: $LAMBDA_ROLE_NAME"
fi

# Step 6: Delete KB access role in agent-kb account
echo "Step 6: Deleting KB access role in agent-kb account..."

if aws iam get-role --role-name "$KB_ACCESS_ROLE_NAME" --profile "$AGENT_KB_PROFILE" >/dev/null 2>&1; then
    aws iam delete-role \
      --role-name "$KB_ACCESS_ROLE_NAME" \
      --profile "$AGENT_KB_PROFILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ KB access role deleted: $KB_ACCESS_ROLE_NAME"
    else
        echo "❌ Failed to delete KB access role: $KB_ACCESS_ROLE_NAME"
        echo "   This may be because the role is still attached to other policies or resources."
    fi
else
    echo "⚠️  KB access role does not exist: $KB_ACCESS_ROLE_NAME"
fi

echo ""
echo "=========================================="
echo "DELETION SUMMARY"
echo "=========================================="
echo ""
echo "AGENT ACCOUNT ($AGENT_ACCOUNT_NUMBER):"
echo "  Lambda Role: $LAMBDA_ROLE_NAME"
echo "  Lambda Policy: $LAMBDA_POLICY_NAME"
echo ""
echo "AGENT-KB ACCOUNT ($AGENT_KB_ACCOUNT_NUMBER):"
echo "  KB Access Role: $KB_ACCESS_ROLE_NAME"
echo "  KB Access Policy: $KB_ACCESS_POLICY_NAME"
echo ""
echo "=========================================="
echo "✅ Deletion process completed!"
echo "=========================================="
echo ""
echo "Note: If any deletions failed, it may be because:"
echo "1. Resources are still in use by other AWS services"
echo "2. There are additional policies attached to the roles"
echo "3. Resources were already deleted"
echo ""
echo "You can manually check and clean up any remaining resources if needed."