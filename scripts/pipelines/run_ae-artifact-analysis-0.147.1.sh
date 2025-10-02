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
  AEAA_0_147_1_DIR="$WORKSPACE_001_DIR/ae-artifact-analysis-0.147.1"
  readonly CURATED_DIR="$AEAA_0_147_1_DIR/03_curated"
  readonly RESOLVED_DIR="$AEAA_0_147_1_DIR/04_resolved"
  readonly ADVISED_DIR="$AEAA_0_147_1_DIR/05_advised"
  readonly TMP_DIR="$AEAA_0_147_1_DIR/99_tmp"

  ENV_REFERENCE_INVENTORY_DIR="$PRODUCT_WORKBENCH_DIR/inventories/example-reference-inventory/inventory"
  ENV_SECURITY_POLICY_FILE="$PRODUCT_WORKBENCH_DIR/policies/security-policy.json"

}

prepare() {
  local param_group_id="com.metaeffekt.artifact.analysis"
  local param_artifact_id="ae-artifact-analysis"
  local param_version="0.147.1"
  local param_exclude_transitive_enabled="false"
  local output_dependencies_dir="$AEAA_0_147_1_DIR/01_prepared"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/prepare/prepare_copy-pom-dependencies.xml" process-resources)
  CMD+=("-Dparam.group.id=$param_group_id")
  CMD+=("-Dparam.artifact.id=$param_artifact_id")
  CMD+=("-Dparam.version=$param_version")
  CMD+=("-Dparam.exclude.transitive.enabled=$param_exclude_transitive_enabled")
  CMD+=("-Doutput.dependencies.dir=$output_dependencies_dir")


    log_info "Running copy dependencies step."

    log_config "" "output.dependencies.dir=$output_dependencies_dir"

    log_mvn "${CMD[*]}"

    if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
        log_info "Successfully ran copy dependencies step."
    else
        log_error "Failed to run copy dependencies step because the maven execution was unsuccessful"
        return 1
    fi
}

extract() {

  local input_reference_inventory_dir="$EXTERNAL_WORKBENCH_DIR/inventories/example-reference-inventory"
  local input_extracts_dir="$AEAA_0_147_1_DIR/01_prepared"
  local output_scan_dir="$AEAA_0_147_1_DIR/02_extracted/scanned"
  local output_inventory_file="$AEAA_0_147_1_DIR/02_extracted/ae-artifact-analysis-0.147.1-extracted.xlsx"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/extract/extract_scan-directory.xml" process-resources)
  CMD+=("-Dinput.reference.inventory.dir=$input_reference_inventory_dir")
  CMD+=("-Dinput.extract.dir=$input_extracts_dir")
  CMD+=("-Doutput.scan.dir=$output_scan_dir")
  CMD+=("-Doutput.inventory.file=$output_inventory_file")


  log_info "Running scan dependencies step."

  log_config "input.reference.inventory.dir=$input_reference_inventory_dir
              input.extract.dir=$input_extracts_dir" "
              output.scan.dir=$output_scan_dir
              output.inventory.file=$output_inventory_file"

  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran scan dependencies step."
  else
      log_error "Failed to run scan dependencies step because the maven execution was unsuccessful"
      return 1
  fi
}

resolve() {
  local input_inventory_file="$AEAA_0_147_1_DIR/02_extracted/ae-artifact-analysis-0.147.1-extracted.xlsx"
  local input_artifact_resolver_config_file="$CONFIGS_DIR/resolver/artifact-resolver-config.yaml"
  local input_artifact_resolver_proxy_file="$CONFIGS_DIR/resolver/artifact-resolver-proxy.yaml"
  local output_inventory_file="$AEAA_0_147_1_DIR/04_resolved/ae-artifact-analysis-0.147.1-resolved.xlsx"
  local env_maven_index_dir="$SELF_DIR/.maven-index"

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

export_cyclonedx() {
  local input_inventory_file="$AEAA_0_147_1_DIR/04_resolved/ae-artifact-analysis-0.147.1-resolved.xlsx"
  local param_document_name="ae-artifact-analysis resolved"
  local param_document_description="An SBOM of the metaeffekt artifact-analysis project, produced after the extracted artifacts were resolved."
  local param_document_organization="{metaeffekt} GmbH"
  local param_document_organization_url="https://metaeffekt.com"
  local output_bom_file="$AEAA_0_147_1_DIR/04_resolved/ae-artifact-analysis-0.147.1-resolved-cyclonedx.json"
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


enrich_inventory_with_reference() {
  log_info "Running processor enrich_inventory_with_reference process."

  ANALYZED_INVENTORY_FILE="$RESOLVED_DIR/ae-artifact-analysis-0.147.1-resolved.xlsx"
  CURATED_INVENTORY_DIR="$CURATED_DIR/ae-artifact-analysis-0.147.1"
  CURATED_INVENTORY_PATH="ae-artifact-analysis-0.147.1-inventory.xlsx"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/advise/advise_enrich-with-reference.xml" process-resources)
  CMD+=("-Dinput.inventory.file=$ANALYZED_INVENTORY_FILE")
  CMD+=("-Dinput.reference.inventory.dir=$ENV_REFERENCE_INVENTORY_DIR")
  CMD+=("-Doutput.inventory.dir=$CURATED_INVENTORY_DIR")
  CMD+=("-Doutput.inventory.path=$CURATED_INVENTORY_PATH")

  log_config "input.inventory.file=$ANALYZED_INVENTORY_FILE
              input.reference.inventory.dir=$ENV_REFERENCE_INVENTORY_DIR" "
              output.inventory.dir=$CURATED_INVENTORY_DIR
              output.inventory.path=$CURATED_INVENTORY_PATH"


  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran enrich_inventory_with_reference"
  else
      log_error "Failed to run enrich_inventory_with_reference because the maven execution was unsuccessful"
      return 1
  fi
}

advise() {
  log_info "Running processor enrich_inventory process."

  ASSESSMENT_DIR="$PRODUCT_WORKBENCH_DIR/assessments/example-001"
  CONTEXT_DIR="$PRODUCT_WORKBENCH_DIR/contexts/example-001"
  CORRELATION_DIR="$PRODUCT_WORKBENCH_DIR/correlations/shared"
  ADVISED_INVENTORY_FILE="$ADVISED_DIR/ae-artifact-analysis-0.147.1-advised.xlsx"
  PROCESSOR_TMP_DIR="$TMP_DIR/processor"

  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/advise/advise_enrich-inventory.xml" process-resources)
  CMD+=("-Dinput.inventory.file=$CURATED_INVENTORY_DIR/$CURATED_INVENTORY_PATH")
  CMD+=("-Dinput.security.policy.file=$ENV_SECURITY_POLICY_FILE")

  # these are params
  CMD+=("-Dinput.assessment.dir=$ASSESSMENT_DIR")
  CMD+=("-Dinput.correlation.dir=$CORRELATION_DIR")
  CMD+=("-Dinput.context.dir=$CONTEXT_DIR")

  # these are envs
  CMD+=("-Doutput.inventory.file=$ADVISED_INVENTORY_FILE")
  CMD+=("-Doutput.tmp.dir=$PROCESSOR_TMP_DIR")
  CMD+=("-Denv.vulnerability.mirror.dir=$EXTERNAL_VULNERABILITY_MIRROR_DIR")

  log_config "input.inventory.file=$CURATED_INVENTORY_DIR/$CURATED_INVENTORY_PATH
              input.security.policy.file=$ENV_SECURITY_POLICY_FILE" "
              output.inventory.file=$ADVISED_INVENTORY_FILE
              output.tmp.dir=$PROCESSOR_TMP_DIR"

  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran enrich_inventory"
  else
      log_error "Failed to run enrich_inventory because the maven execution was unsuccessful"
      return 1
  fi
}

generate_vulnerability_assessment_dashboard() {
  log_info "Running processor generate_vulnerability_assessment_dashboard process."

  OUTPUT_DASHBOARD_FILE="$ADVISED_DIR/dashboards/ae-artifact-analysis-0.147.1-dashboard.html"
  CMD=(mvn -f "$KONTINUUM_PROCESSORS_DIR/advise/advise_create-dashboard.xml" process-resources)
  CMD+=("-Dinput.inventory.file=$ADVISED_INVENTORY_FILE")
  CMD+=("-Dinput.security.policy.file=$ENV_SECURITY_POLICY_FILE")
  CMD+=("-Doutput.dashboard.file=$OUTPUT_DASHBOARD_FILE")
  CMD+=("-Denv.vulnerability.mirror.dir=$EXTERNAL_VULNERABILITY_MIRROR_DIR")

  log_config "input.inventory.file=$ADVISED_INVENTORY_FILE
              input.security.policy.file=$ENV_SECURITY_POLICY_FILE" "
              output.dashboard.file=$OUTPUT_DASHBOARD_FILE"

  log_mvn "${CMD[*]}"

  if "${CMD[@]}" 2>&1 | while IFS= read -r line; do log_mvn "$line"; done; then
      log_info "Successfully ran generate_vulnerability_assessment_dashboard"
  else
      log_error "Failed to run generate_vulnerability_assessment_dashboard because the maven execution was unsuccessful"
      return 1
  fi
}

main() {
    source_preload
    set_global_variables

    SCRIPT_NAME=$(basename "$(readlink -f "$0")")
    LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}.log"
    logger_init "ALL" "$LOG_FILE" true
    # Logger can be used starting here

    prepare
    extract
    resolve
    export_cyclonedx
    enrich_inventory_with_reference
    advise
    generate_vulnerability_assessment_dashboard
}

main "$@"