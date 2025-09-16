#!/bin/bash

# Exit on any error
set -euo pipefail

readonly SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source_preload() {
  if [ -f "$SELF_DIR/../shared/preload.sh" ];then
    source "$SELF_DIR/../shared/preload.sh"
    echo "Successfully sourced preload.sh file"
  else
    echo "Terminating: preload.sh script not found."
    exit 1
  fi
}

set_global_variables() {
  # The variables set in this method can/should be outsourced to a shared script if the number of pipelines
  # keeps growing. The variables could also be put into a .rc file akin to the external.rc file and sourced by the
  # different pipelines to provide a better overview.
  readonly PRODUCT_WORKBENCH_DIR="$SELF_DIR/../.."
  readonly WORKSPACE_001_DIR="$PRODUCT_WORKBENCH_DIR/workspace-001"

  # Global Variables
  LOG_DIR="$PRODUCT_WORKBENCH_DIR/.logs"
  CONFIGS_DIR="$PRODUCT_WORKBENCH_DIR/configs"
  KONTINUUM_PROCESSORS_DIR="$EXTERNAL_KONTINUUM_DIR/processors"
  AEAA_0_137_0_DIR="$WORKSPACE_001_DIR/ae-artifact-analysis-0.137.0"

}

resolve() {
  local input_inventory_file="$AEAA_0_137_0_DIR/01_analyzed/ae-artifact-analysis-0.137.0-analyzed.xlsx"
  local input_artifact_resolver_config_file="$CONFIGS_DIR/resolver/artifact-resolver-config.yaml"
  local input_artifact_resolver_proxy_file="$CONFIGS_DIR/resolver/artifact-resolver-proxy.yaml"
  local output_inventory_file="$AEAA_0_137_0_DIR/02_resolved/ae-artifact-analysis-0.137.0-resolved.xlsx"
  local env_maven_index_dir="$AEAA_0_137_0_DIR/02_resolved/maven-index"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/analyze/analyze_resolve-inventory.xml" process-resources)
  CMD+=("-Dinput.inventory.file=$input_inventory_file")
  CMD+=("-Dinput.artifact.resolver.config.file=$input_artifact_resolver_config_file")
  CMD+=("-Dinput.artifact.resolver.proxy.file=$input_artifact_resolver_proxy_file")
  CMD+=("-Doutput.inventory.file=$output_inventory_file")
  CMD+=("-Denv.maven.index.dir=$env_maven_index_dir")

  log_info "Running resolve step."

  log_config "input.inventory.file=$input_inventory_file
             input.artifact.resolver.config.file=$input_artifact_resolver_config_file
             input.artifact.resolver.proxy.file=$input_artifact_resolver_proxy_file" "
             output.inventory.file=$output_inventory_file"

  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran resolve step."
  else
      log_error "Failed to run resolve step because the maven execution was unsuccessful."
      return 1
  fi
}

resolved_inventory_to_cyclonedx() {
  local input_inventory_file="$AEAA_0_137_0_DIR/02_resolved/ae-artifact-analysis-0.137.0-resolved.xlsx"
  local param_document_name="ae-artifact-analysis resolved"
  local param_document_description="An SBOM of the metaeffekt artifact-analysis project, produced after the extracted artifacts were resolved."
  local param_document_organization="{metaeffekt} GmbH"
  local param_document_organization_url="https://metaeffekt.com"
  local output_bom_file="$AEAA_0_137_0_DIR/02_resolved/ae-artifact-analysis-0.137.0-resolved-cyclonedx.json"
  local output_format="JSON"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/convert/convert_inventory-to-cyclonedx.xml" process-resources)
  CMD+=("-Dinput.inventory.file=$input_inventory_file")
  CMD+=("-Dparam.document.name=$param_document_name")
  CMD+=("-Dparam.document.description=$param_document_description")
  CMD+=("-Dparam.document.organization=$param_document_organization")
  CMD+=("-Dparam.document.organization.url=$param_document_organization_url")
  CMD+=("-Doutput.bom.file=$output_bom_file")
  CMD+=("-Doutput.format=$output_format")

  log_info "Running processor $KONTINUUM_PROCESSORS_DIR/convert/convert_inventory-to-cyclonedx.xml"

  log_config "input.inventory.file=$input_inventory_file" "output.bom.file=$output_bom_file"

  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran $KONTINUUM_PROCESSORS_DIR/convert/convert_inventory-to-cyclonedx.xml"
  else
      log_error "Failed to run $KONTINUUM_PROCESSORS_DIR/convert/convert_inventory-to-cyclonedx.xml because the maven execution was unsuccessful"
      return 1
  fi
}

main() {
    source_preload
    set_global_variables
    # Logger can be used starting here
    SCRIPT_NAME=$(basename "$(readlink -f "$0")")
    LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}.log"
    logger_init "CONFIG" "$LOG_FILE" true

    resolve
    resolved_inventory_to_cyclonedx
}

main "$@"