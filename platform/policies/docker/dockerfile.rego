# OPA Policy: Dockerfile Security Requirements
# Enforces enterprise Docker security standards
#
# These policies run in CI pipeline via Conftest
# PROBLEM: Policies run IN the workflow - can be bypassed by developers
# MITIGATION: Required status checks + protected workflows

package docker

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ==============================================================================
# APPROVED BASE IMAGES
# ==============================================================================
approved_base_images := {
    "node:20-alpine",
    "node:18-alpine",
    "golang:1.21-alpine",
    "python:3.11-slim",
    "python:3.12-slim",
    "alpine:3.19",
}

# DENY: Unapproved base images
deny[msg] {
    input[i].Cmd == "from"
    base_image := input[i].Value[0]

    # Extract image without tag/digest
    image_parts := split(base_image, "@")
    image_with_tag := image_parts[0]
    image_name_parts := split(image_with_tag, ":")

    not base_image_approved(image_with_tag)

    msg := sprintf("Unapproved base image: '%s'. Must use one of: %v", [base_image, approved_base_images])
}

base_image_approved(image) {
    startswith(image, approved_base_images[_])
}

# ==============================================================================
# REQUIRE NON-ROOT USER
# ==============================================================================
deny[msg] {
    # Check if USER instruction exists
    not has_user_instruction

    msg := "Dockerfile must specify a non-root USER instruction"
}

has_user_instruction {
    input[_].Cmd == "user"
}

# DENY: Running as root
deny[msg] {
    input[i].Cmd == "user"
    user := input[i].Value[0]
    user == "root"

    msg := "Cannot run container as root user. Must use non-root user (e.g., USER 1001)"
}

# ==============================================================================
# REQUIRE HEALTHCHECK
# ==============================================================================
warn[msg] {
    not has_healthcheck

    msg := "Dockerfile should include a HEALTHCHECK instruction for container orchestration"
}

has_healthcheck {
    input[_].Cmd == "healthcheck"
}

# ==============================================================================
# DENY PRIVILEGED OPERATIONS
# ==============================================================================
deny[msg] {
    input[i].Cmd == "run"
    command := concat(" ", input[i].Value)

    contains(lower(command), "chmod 777")

    msg := "Prohibited: chmod 777 grants excessive permissions"
}

deny[msg] {
    input[i].Cmd == "run"
    command := concat(" ", input[i].Value)

    contains(lower(command), "curl")
    contains(lower(command), "bash")
    not contains(lower(command), "ca-certificates")

    msg := "Warning: Downloading and executing scripts is risky. Ensure verification."
}

# ==============================================================================
# REQUIRE PACKAGE MANAGER BEST PRACTICES
# ==============================================================================
warn[msg] {
    input[i].Cmd == "run"
    command := concat(" ", input[i].Value)

    contains(command, "npm install")
    not contains(command, "npm ci")

    msg := "Recommendation: Use 'npm ci' instead of 'npm install' for deterministic builds"
}

warn[msg] {
    input[i].Cmd == "run"
    command := concat(" ", input[i].Value)

    contains(command, "apt-get install")
    not contains(command, "--no-install-recommends")

    msg := "Recommendation: Use 'apt-get install --no-install-recommends' to minimize image size"
}

# ==============================================================================
# DENY SECRETS IN IMAGE
# ==============================================================================
deny[msg] {
    input[i].Cmd == "env"
    env_value := concat("=", input[i].Value)

    contains(lower(env_value), "password")
    msg := "Prohibited: Environment variables should not contain 'password'. Use secrets management."
}

deny[msg] {
    input[i].Cmd == "env"
    env_value := concat("=", input[i].Value)

    contains(lower(env_value), "api_key")
    msg := "Prohibited: Environment variables should not contain 'api_key'. Use secrets management."
}

# ==============================================================================
# REQUIRE EXPLICIT VERSIONS
# ==============================================================================
warn[msg] {
    input[i].Cmd == "from"
    base_image := input[i].Value[0]

    # Check if using 'latest' tag
    endswith(base_image, ":latest")

    msg := "Warning: Avoid 'latest' tag. Pin to specific version or digest for reproducibility."
}

# ==============================================================================
# COPY OPERATIONS SECURITY
# ==============================================================================
warn[msg] {
    input[i].Cmd == "copy"
    not has_chown_flag(input[i])

    msg := "Recommendation: Use 'COPY --chown=user:group' to set correct ownership"
}

has_chown_flag(instruction) {
    contains(instruction.Flags[_], "--chown")
}

# ==============================================================================
# EXPOSE PORTS
# ==============================================================================
warn[msg] {
    input[i].Cmd == "expose"
    port := to_number(input[i].Value[0])

    port < 1024

    msg := sprintf("Warning: Exposing privileged port %d. Non-root users cannot bind to ports < 1024.", [port])
}
