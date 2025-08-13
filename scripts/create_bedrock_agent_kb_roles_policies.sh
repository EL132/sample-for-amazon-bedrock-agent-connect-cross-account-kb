#!/bin/bash

# Script to create Bedrock KB cross-account roles and policies
# Usage: ./create-bedrock-agent-kb-roles-policies.sh --agent-profile <profile> --agent-kb-profile <profile> [options]

# Don't use set -e to allow proper error handling
set -o pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [Required Parameters]"
    echo ""
    echo "Required Parameters:"
    echo "  --agent-profile <profile>         AWS CLI profile for agent account"
    echo "  --agent-kb-profile <profile>      AWS CLI profile for agent-kb account"
    echo "  --lambda-role <name>              Name for Lambda execution role"
    echo "  --kb-access-role <name>           Name for KB access role"
    echo "  --kb-access-policy <name>         Name for KB access policy"
    echo "  --lambda-policy <name>            Name for Lambda policy"
    echo "  --knowledge-base-id <id>          Bedrock Knowledge Base ID"
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
    echo "     --knowledge-base-id XXXXXXXXXX \\"
    echo "     --agent-account 000000000000 \\"
    echo "     --agent-kb-account 999999999999"
    echo ""
    echo "Another Example:"
    echo "  $0 --agent-profile myagent \\"
    echo "     --agent-kb-profile mykb \\"
    echo "     --lambda-role my-lambda-role \\"
    echo "     --kb-access-role my-kb-role \\"
    echo "     --kb-access-policy my-kb-policy \\"
    echo "     --lambda-policy my-lambda-policy \\"
    echo "     --knowledge-base-id ABC123XYZ \\"
    echo "     --agent-account 123456789012 \\"
    echo "     --agent-kb-account 987654321098"
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
        --knowledge-base-id)
            KNOWLEDGE_BASE_ID="$2"
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

if [[ -z "$KNOWLEDGE_BASE_ID" ]]; then
    MISSING_PARAMS+=("--knowledge-base-id")
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
echo "Creating Bedrock KB Cross-Account Roles"
echo "=========================================="
echo "Agent Profile: $AGENT_PROFILE"
echo "Agent-KB Profile: $AGENT_KB_PROFILE"
echo "Lambda Role: $LAMBDA_ROLE_NAME"
echo "KB Access Role: $KB_ACCESS_ROLE_NAME"
echo "KB Access Policy: $KB_ACCESS_POLICY_NAME"
echo "Lambda Policy: $LAMBDA_POLICY_NAME"
echo "Knowledge Base ID: $KNOWLEDGE_BASE_ID"
echo "Agent Account: $AGENT_ACCOUNT_NUMBER"
echo "Agent-KB Account: $AGENT_KB_ACCOUNT_NUMBER"
echo "=========================================="

# Validate AWS CLI profiles before proceeding
echo "Validating AWS CLI profiles..."

# Check agent profile
echo "Checking agent profile: $AGENT_PROFILE"
AGENT_IDENTITY=$(aws sts get-caller-identity --profile "$AGENT_PROFILE" 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Failed to validate agent profile '$AGENT_PROFILE'. Error:"
    echo "$AGENT_IDENTITY"
    echo ""
    echo "Please ensure the profile is configured correctly:"
    echo "  aws configure --profile $AGENT_PROFILE"
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
    echo ""
    echo "Please ensure the profile is configured correctly:"
    echo "  aws configure --profile $AGENT_KB_PROFILE"
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

# Step 1: Create Lambda role in agent account
echo "Step 1: Creating Lambda role in agent account..."

# First check if role already exists
if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --profile "$AGENT_PROFILE" >/dev/null 2>&1; then
    echo "⚠️  Lambda role already exists, getting existing ARN..."
    LAMBDA_ROLE_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --profile "$AGENT_PROFILE" --query 'Role.Arn' --output text)
    echo "✓ Lambda role: $LAMBDA_ROLE_ARN"
else
    # Try to create the role
    echo "Creating new Lambda role..."
    CREATE_ROLE_RESULT=$(aws iam create-role \
      --role-name "$LAMBDA_ROLE_NAME" \
      --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }' \
      --profile "$AGENT_PROFILE" \
      --query 'Role.Arn' \
      --output text 2>&1)
    
    if [ $? -eq 0 ]; then
        LAMBDA_ROLE_ARN="$CREATE_ROLE_RESULT"
        echo "✓ Lambda role created: $LAMBDA_ROLE_ARN"
    else
        echo "❌ Failed to create Lambda role. Error details:"
        echo "$CREATE_ROLE_RESULT"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify that the profile '$AGENT_PROFILE' is configured correctly:"
        echo "   aws sts get-caller-identity --profile $AGENT_PROFILE"
        echo "2. Check that you have IAM permissions in the agent account"
        echo "3. Verify the role name is valid: $LAMBDA_ROLE_NAME"
        exit 1
    fi
fi

# Step 2: Create Bedrock KB access role in agent-kb account
echo "Step 2: Creating Bedrock KB access role in agent-kb account..."

# First check if role already exists
if aws iam get-role --role-name "$KB_ACCESS_ROLE_NAME" --profile "$AGENT_KB_PROFILE" >/dev/null 2>&1; then
    echo "⚠️  KB access role already exists, getting existing ARN..."
    KB_ACCESS_ROLE_ARN=$(aws iam get-role --role-name "$KB_ACCESS_ROLE_NAME" --profile "$AGENT_KB_PROFILE" --query 'Role.Arn' --output text)
    echo "✓ KB access role: $KB_ACCESS_ROLE_ARN"
else
    # Try to create the role
    echo "Creating new KB access role..."
    
    # Create temporary file for error output
    ERROR_FILE=$(mktemp)
    
    # First, verify the Lambda role exists and get its actual ARN
    echo "Verifying Lambda role exists before creating trust relationship..."
    ACTUAL_LAMBDA_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --profile "$AGENT_PROFILE" --query 'Role.Arn' --output text 2>/dev/null)
    if [[ -z "$ACTUAL_LAMBDA_ARN" ]]; then
        echo "❌ Lambda role '$LAMBDA_ROLE_NAME' does not exist in agent account $AGENT_ACCOUNT_NUMBER"
        echo "Cannot create cross-account trust relationship to non-existent role."
        exit 1
    fi
    echo "✓ Lambda role verified: $ACTUAL_LAMBDA_ARN"
    
    # Wait a moment for role propagation
    echo "Waiting 5 seconds for role propagation..."
    sleep 5
    
    # Create the assume role policy document using jq for perfect JSON formatting
    POLICY_FILE=$(mktemp)
    
    # Create JSON using the actual Lambda ARN we retrieved
    jq -n \
      --arg lambda_arn "$ACTUAL_LAMBDA_ARN" \
      '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "AWS": $lambda_arn
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }' > "$POLICY_FILE"
    
    # Debug: Show the generated policy document
    echo "Generated assume role policy document:"
    cat "$POLICY_FILE"
    echo ""
    
    # Execute the command and capture both stdout and stderr separately
    CREATE_ROLE_RESULT=$(aws iam create-role \
      --role-name "$KB_ACCESS_ROLE_NAME" \
      --assume-role-policy-document "file://$POLICY_FILE" \
      --profile "$AGENT_KB_PROFILE" \
      --query 'Role.Arn' \
      --output text 2>"$ERROR_FILE")
    
    COMMAND_EXIT_CODE=$?
    
    if [ $COMMAND_EXIT_CODE -eq 0 ]; then
        KB_ACCESS_ROLE_ARN="$CREATE_ROLE_RESULT"
        echo "✓ KB access role created: $KB_ACCESS_ROLE_ARN"
        rm -f "$ERROR_FILE" "$POLICY_FILE"
    else
        echo "❌ Failed to create KB access role. AWS CLI Error Details:"
        echo "Exit Code: $COMMAND_EXIT_CODE"
        echo "Error Output:"
        cat "$ERROR_FILE"
        echo ""
        echo "Command that failed:"
        echo "aws iam create-role --role-name \"$KB_ACCESS_ROLE_NAME\" --profile \"$AGENT_KB_PROFILE\" [...]"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify that the profile '$AGENT_KB_PROFILE' is configured correctly:"
        echo "   aws sts get-caller-identity --profile $AGENT_KB_PROFILE"
        echo "2. Check that you have IAM permissions in the agent-kb account"
        echo "3. Verify the agent account number: $AGENT_ACCOUNT_NUMBER"
        echo "4. Ensure the Lambda role exists in agent account: $LAMBDA_ROLE_NAME"
        echo "5. Check if the role name is valid and doesn't conflict with existing roles"
        echo "6. Verify the assume role policy document is valid JSON"
        rm -f "$ERROR_FILE" "$POLICY_FILE"
        exit 1
    fi
fi

# Step 3: Create Bedrock KB access policy in agent-kb account
echo "Step 3: Creating Bedrock KB access policy in agent-kb account..."

# Check if policy already exists
EXISTING_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$KB_ACCESS_POLICY_NAME'].Arn" --output text --profile "$AGENT_KB_PROFILE" 2>/dev/null)

if [[ -n "$EXISTING_POLICY_ARN" ]]; then
    echo "⚠️  KB access policy already exists, using existing ARN..."
    KB_ACCESS_POLICY_ARN="$EXISTING_POLICY_ARN"
    echo "✓ KB access policy: $KB_ACCESS_POLICY_ARN"
else
    # Try to create the policy
    echo "Creating new KB access policy..."
    CREATE_POLICY_RESULT=$(aws iam create-policy \
      --policy-name "$KB_ACCESS_POLICY_NAME" \
      --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": "bedrock:Retrieve",
              "Resource": "arn:aws:bedrock:*:*:knowledge-base/'$KNOWLEDGE_BASE_ID'"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": "bedrock:InvokeModel",
              "Resource": "arn:aws:bedrock:us-west-2::foundation-model/meta.llama3-1-70b-instruct-v1:0"
          },
          {
              "Sid": "VisualEditor2",
              "Effect": "Allow",
              "Action": "bedrock:RetrieveAndGenerate",
              "Resource": "arn:aws:bedrock:*:*:knowledge-base/'$KNOWLEDGE_BASE_ID'"
          }
      ]
    }' \
      --profile "$AGENT_KB_PROFILE" \
      --query 'Policy.Arn' \
      --output text 2>&1)
    
    if [ $? -eq 0 ]; then
        KB_ACCESS_POLICY_ARN="$CREATE_POLICY_RESULT"
        echo "✓ KB access policy created: $KB_ACCESS_POLICY_ARN"
    else
        echo "❌ Failed to create KB access policy. Error details:"
        echo "$CREATE_POLICY_RESULT"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify that the profile '$AGENT_KB_PROFILE' is configured correctly"
        echo "2. Check that you have IAM permissions in the agent-kb account"
        echo "3. Verify the knowledge base ID: $KNOWLEDGE_BASE_ID"
        echo "4. Check if the policy name is valid: $KB_ACCESS_POLICY_NAME"
        exit 1
    fi
fi

# Step 4: Attach KB access policy to KB access role
echo "Step 4: Attaching KB access policy to KB access role..."
aws iam attach-role-policy \
  --role-name "$KB_ACCESS_ROLE_NAME" \
  --policy-arn "$KB_ACCESS_POLICY_ARN" \
  --profile "$AGENT_KB_PROFILE" 2>/dev/null || echo "⚠️  Policy may already be attached"

echo "✓ KB access policy attached to KB access role"

# Step 5: Create Lambda policy in agent account
echo "Step 5: Creating Lambda policy in agent account..."

# Check if policy already exists
EXISTING_LAMBDA_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$LAMBDA_POLICY_NAME'].Arn" --output text --profile "$AGENT_PROFILE" 2>/dev/null)

if [[ -n "$EXISTING_LAMBDA_POLICY_ARN" ]]; then
    echo "⚠️  Lambda policy already exists, using existing ARN..."
    LAMBDA_POLICY_ARN="$EXISTING_LAMBDA_POLICY_ARN"
    echo "✓ Lambda policy: $LAMBDA_POLICY_ARN"
else
    # Try to create the policy
    echo "Creating new Lambda policy..."
    CREATE_LAMBDA_POLICY_RESULT=$(aws iam create-policy \
      --policy-name "$LAMBDA_POLICY_NAME" \
      --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Resource": "arn:aws:iam::'$AGENT_KB_ACCOUNT_NUMBER':role/'$KB_ACCESS_ROLE_NAME'"
          }
      ]
    }' \
      --profile "$AGENT_PROFILE" \
      --query 'Policy.Arn' \
      --output text 2>&1)
    
    if [ $? -eq 0 ]; then
        LAMBDA_POLICY_ARN="$CREATE_LAMBDA_POLICY_RESULT"
        echo "✓ Lambda policy created: $LAMBDA_POLICY_ARN"
    else
        echo "❌ Failed to create Lambda policy. Error details:"
        echo "$CREATE_LAMBDA_POLICY_RESULT"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify that the profile '$AGENT_PROFILE' is configured correctly"
        echo "2. Check that you have IAM permissions in the agent account"
        echo "3. Verify the agent-kb account number: $AGENT_KB_ACCOUNT_NUMBER"
        echo "4. Verify the KB access role name: $KB_ACCESS_ROLE_NAME"
        echo "5. Check if the policy name is valid: $LAMBDA_POLICY_NAME"
        exit 1
    fi
fi

# Step 6: Attach Lambda policy to Lambda role
echo "Step 6: Attaching Lambda policy to Lambda role..."
aws iam attach-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-arn "$LAMBDA_POLICY_ARN" \
  --profile "$AGENT_PROFILE" 2>/dev/null || echo "⚠️  Policy may already be attached"

echo "✓ Lambda policy attached to Lambda role"

# Step 7: Attach AWS managed policy to Lambda role
echo "Step 7: Attaching AWSLambdaBasicExecutionRole to Lambda role..."
aws iam attach-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --profile "$AGENT_PROFILE" 2>/dev/null || echo "⚠️  Policy may already be attached"

echo "✓ AWSLambdaBasicExecutionRole attached to Lambda role"

echo ""
echo "=========================================="
echo "SUMMARY - Resources Created"
echo "=========================================="
echo ""
echo "AGENT ACCOUNT ($AGENT_ACCOUNT_NUMBER):"
echo "  Lambda Role Name: $LAMBDA_ROLE_NAME"
echo "  Lambda Role ARN:  $LAMBDA_ROLE_ARN"
echo "  Lambda Policy Name: $LAMBDA_POLICY_NAME"
echo "  Lambda Policy ARN:  $LAMBDA_POLICY_ARN"
echo ""
echo "AGENT-KB ACCOUNT ($AGENT_KB_ACCOUNT_NUMBER):"
echo "  KB Access Role Name: $KB_ACCESS_ROLE_NAME"
echo "  KB Access Role ARN:  $KB_ACCESS_ROLE_ARN"
echo "  KB Access Policy Name: $KB_ACCESS_POLICY_NAME"
echo "  KB Access Policy ARN:  $KB_ACCESS_POLICY_ARN"
echo ""
echo "CONFIGURATION:"
echo "  Knowledge Base ID: $KNOWLEDGE_BASE_ID"
echo "  Foundation Model: meta.llama3-1-70b-instruct-v1:0"
echo ""
echo "=========================================="
echo "✅ All resources created successfully!"
echo "=========================================="

# Output JSON format for easy parsing
echo ""
echo "JSON OUTPUT:"
cat << EOF
{
  "agent_account": {
    "account_number": "$AGENT_ACCOUNT_NUMBER",
    "lambda_role": {
      "name": "$LAMBDA_ROLE_NAME",
      "arn": "$LAMBDA_ROLE_ARN"
    },
    "lambda_policy": {
      "name": "$LAMBDA_POLICY_NAME",
      "arn": "$LAMBDA_POLICY_ARN"
    }
  },
  "agent_kb_account": {
    "account_number": "$AGENT_KB_ACCOUNT_NUMBER",
    "kb_access_role": {
      "name": "$KB_ACCESS_ROLE_NAME",
      "arn": "$KB_ACCESS_ROLE_ARN"
    },
    "kb_access_policy": {
      "name": "$KB_ACCESS_POLICY_NAME",
      "arn": "$KB_ACCESS_POLICY_ARN"
    }
  },
  "configuration": {
    "knowledge_base_id": "$KNOWLEDGE_BASE_ID",
    "foundation_model": "meta.llama3-1-70b-instruct-v1:0"
  }
}
EOF