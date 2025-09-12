#!/bin/bash

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  readonly WORKSPACE_001_DIR="$SELF_DIR/workspace-001"

  # Global Variables
  export LOG_DIR="$PRODUCT_WORKBENCH_DIR/.logs"
  export CONFIGS_DIR="$PRODUCT_WORKBENCH_DIR/configs"
  export KONTINUUM_PROCESSORS_DIR="$EXTERNAL_KONTINUUM_DIR/processors"
  export AEAA_0_137_0_DIR="$WORKSPACE_001_DIR/ae-artifact-analysis-0.137.0"

  # Global Target Variables
  export WORKSPACE_001_TARGET_DIR="$PRODUCT_WORKBENCH_DIR/target/workspace-001"
  export AEAA_0_137_0_TARGET_DIR="$WORKSPACE_001_TARGET_DIR/ae-artifact-analysis-0.137.0"
}

copy_workspaces_to_target() {
  if [[ -d "$WORKSPACE_001_TARGET_DIR" ]]; then
    log_info "Workspace 001 target directory already exists."
  else
    if mkdir -p "$WORKSPACE_001_TARGET_DIR"; then
      log_info "Created target workspace directory."

      if cp "$WORKSPACE_001_DIR" "$WORKSPACE_001_TARGET_DIR"; then
        log_info "Successfully copied workspace 001 to target."
      else
        log_error "Failed to copy workspace 001 to target."
        exit 1
      fi
    else
      log_error "Failed to create target workspace directories."
      exit 1
    fi
  fi
}

example_step() {
  local input_inventory_file="$AEAA_0_137_0_DIR/01_analyzed/ae-artifact-analysis-0.137.0-analyzed.xlsx"
  local input_artifact_resolver_config_file="$CONFIGS_DIR/resolver/artifact-resolver-config.yaml"
  local input_artifact_resolver_proxy_file="$CONFIGS_DIR/resolver/artifact-resolver-proxy.yaml"
  local output_inventory_file="$WORKSPACE_001_TARGET_DIR/02_resolved/ae-artifact-analysis-0.137.0-resolved.xlsx"
  local env_maven_index_dir="$WORKSPACE_001_TARGET_DIR/02_resolved/maven-index"

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

main() {
    source_preload
    # Logger can be used starting here
    logger_init "CONFIG" "$LOG_DIR/$(basename $0).log" true
    set_global_variables
    copy_workspaces_to_target
    example_step
}

main "$@"