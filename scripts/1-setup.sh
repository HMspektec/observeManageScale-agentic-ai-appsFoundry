#!/bin/bash

set -e

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_URL="https://github.com/microsoft/ForBeginners"
DEFAULT_BRANCH="for-release-1.0.4" 
TARGET_DIR="./ForBeginners"
AZD_SETUP_DIR="./ForBeginners/.azd-setup"

#==============================================================================
# Helper Functions
#==============================================================================

clone_forbeginners_repo() {
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}ForBeginners directory already exists. Skipping clone.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Cloning ForBeginners repository...${NC}"
    read -p "Enter branch name [${DEFAULT_BRANCH}]: " branch_input
    local branch=${branch_input:-$DEFAULT_BRANCH}
    
    echo -e "${YELLOW}Cloning branch: ${branch}${NC}"
    if git clone -b "$branch" --single-branch "$REPO_URL" "$TARGET_DIR"; then
        echo -e "${GREEN}✓ Repository cloned successfully from branch: ${branch}${NC}"
    else
        echo -e "${RED}✗ Failed to clone repository${NC}"
        exit 1
    fi
}

setup_azd_environment() {
    echo -e "${YELLOW}Setting up AZD environment...${NC}"
    
    local existing_env=$(azd env list --output json 2>/dev/null | jq -r '.[0].Name' 2>/dev/null || echo "")
    
    if [ -n "$existing_env" ] && [ "$existing_env" != "null" ]; then
        echo -e "${YELLOW}Found existing AZD environment: ${existing_env}${NC}"
        read -p "Use existing environment? (yes/no): " use_existing
        
        if [ "$use_existing" != "yes" ]; then
            create_new_environment
        fi
    else
        echo -e "${YELLOW}No existing AZD environment found. Creating new one...${NC}"
        create_new_environment
    fi
}

create_new_environment() {
    echo -e "${YELLOW}Creating new AZD environment...${NC}"
    
    read -p "Enter environment name: " env_name
    read -p "Enter Azure region [swedencentral]: " region
    region=${region:-swedencentral}
    read -p "Enter subscription ID (optional): " subscription_id
    
    if [ -n "$subscription_id" ]; then
        azd env new "$env_name" --location "$region" --subscription "$subscription_id"
    else
        azd env new "$env_name" --location "$region"
    fi
    
    echo -e "${GREEN}✓ Environment created${NC}"
}

configure_environment_variables() {
    echo -e "${YELLOW}Configuring environment variables...${NC}"
    
    azd env set USE_APPLICATION_INSIGHTS true
    azd env set ENABLE_AZURE_MONITOR_TRACING true
    azd env set AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED true
    azd env set AZURE_AI_AGENT_DEPLOYMENT_CAPACITY 50 
    azd env set AZURE_AI_AGENT_DEPLOYMENT_NAME gpt-4.1
    azd env set AZURE_AI_AGENT_MODEL_NAME gpt-4.1
    azd env set AZURE_AI_AGENT_MODEL_VERSION 2025-04-14
    
    echo -e "${GREEN}✓ Environment variables configured${NC}"
}

configure_azure_ai_search() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}  Azure AI Search Configuration${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""

    read -p "Do you want to activate Azure AI Search? (yes/no) [no]: " enable_search
    enable_search=${enable_search:-no}
    
    if [ "$enable_search" == "yes" ]; then
        
        SEARCH_INDEX_NAME="zava-products"
        EMBED_MODEL_NAME="text-embedding-3-large"
        EMBED_MODEL_VERSION="1"
        EMBED_MODEL_FORMAT="OpenAI"
        EMBED_DEPLOYMENT_NAME="text-embedding-3-large"
        EMBED_SKU_NAME="Standard"
        EMBED_CAPACITY="50"
        
        azd env set USE_AZURE_AI_SEARCH_SERVICE true
        azd env set AZURE_AI_SEARCH_INDEX_NAME "$SEARCH_INDEX_NAME"
        azd env set AZURE_AI_EMBED_DEPLOYMENT_NAME "$EMBED_DEPLOYMENT_NAME"
        azd env set AZURE_AI_EMBED_MODEL_NAME "$EMBED_MODEL_NAME"
        azd env set AZURE_AI_EMBED_MODEL_VERSION "$EMBED_MODEL_VERSION"
        azd env set AZURE_AI_EMBED_MODEL_FORMAT "$EMBED_MODEL_FORMAT"
        azd env set AZURE_AI_EMBED_DEPLOYMENT_SKU "$EMBED_SKU_NAME"
        azd env set AZURE_AI_EMBED_DEPLOYMENT_CAPACITY "$EMBED_CAPACITY"
        
        echo -e "${GREEN}✓ Azure AI Search configured${NC}"
    else
        azd env set USE_AZURE_AI_SEARCH_SERVICE false
    fi
}

#==============================================================================
# ✅ MODIFIED STEP 5 (USE EXISTING RESOURCES)
#==============================================================================

deploy_infrastructure() {
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}Using existing Azure resources${NC}"
    echo -e "${YELLOW}======================================${NC}"

    read -p "Enter existing Resource Group name: " EXISTING_RG
    read -p "Enter Azure OpenAI service name: " EXISTING_OPENAI
    read -p "Enter Storage Account name: " EXISTING_STORAGE
    read -p "Enter Azure AI Search service name (optional): " EXISTING_SEARCH

    echo -e "${YELLOW}Configuring environment...${NC}"

    azd env set AZURE_RESOURCE_GROUP "$EXISTING_RG"
    azd env set AZURE_OPENAI_NAME "$EXISTING_OPENAI"
    azd env set AZURE_STORAGE_ACCOUNT "$EXISTING_STORAGE"

    if [ -n "$EXISTING_SEARCH" ]; then
        azd env set AZURE_AI_SEARCH_NAME "$EXISTING_SEARCH"
        azd env set USE_AZURE_AI_SEARCH_SERVICE true
    fi

    echo -e "${GREEN}✓ Existing resources configured${NC}"
    echo -e "${GREEN}✓ Skipped infrastructure deployment${NC}"
}

#==============================================================================
# Main Execution
#==============================================================================

echo -e "${YELLOW}Starting setup process...${NC}"

clone_forbeginners_repo

if [ ! -d "$AZD_SETUP_DIR" ]; then
    echo -e "${RED}✗ AZD setup directory not found${NC}"
    exit 1
fi

cd "$AZD_SETUP_DIR"

setup_azd_environment
configure_environment_variables
configure_azure_ai_search
deploy_infrastructure

echo ""
echo -e "${GREEN}Setup Complete!${NC}"
