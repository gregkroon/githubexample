# OPA Policy: Kubernetes Security Standards
# Enforces Pod Security Standards (PSS) baseline + restricted
# Based on: https://kubernetes.io/docs/concepts/security/pod-security-standards/

package kubernetes

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ==============================================================================
# DENY: PRIVILEGED CONTAINERS
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true

    msg := sprintf("Container '%s' must not run in privileged mode", [container.name])
}

# ==============================================================================
# DENY: HOST PATH VOLUMES
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath

    msg := sprintf("HostPath volumes are prohibited. Found volume: '%s'", [volume.name])
}

# ==============================================================================
# DENY: HOST NETWORK
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostNetwork == true

    msg := "Pods must not use hostNetwork=true"
}

# ==============================================================================
# DENY: HOST PID/IPC
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostPID == true

    msg := "Pods must not use hostPID=true"
}

deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostIPC == true

    msg := "Pods must not use hostIPC=true"
}

# ==============================================================================
# REQUIRE: RUN AS NON-ROOT
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.runAsNonRoot

    msg := "Pod securityContext must set runAsNonRoot=true"
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext

    msg := sprintf("Container '%s' must define securityContext", [container.name])
}

# ==============================================================================
# REQUIRE: DROP ALL CAPABILITIES
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not capabilities_dropped(container)

    msg := sprintf("Container '%s' must drop ALL capabilities", [container.name])
}

capabilities_dropped(container) {
    container.securityContext.capabilities.drop[_] == "ALL"
}

# ==============================================================================
# DENY: PRIVILEGE ESCALATION
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation != false

    msg := sprintf("Container '%s' must set allowPrivilegeEscalation=false", [container.name])
}

# ==============================================================================
# REQUIRE: READ-ONLY ROOT FILESYSTEM
# ==============================================================================
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem

    msg := sprintf("Container '%s' should use readOnlyRootFilesystem=true", [container.name])
}

# ==============================================================================
# REQUIRE: RESOURCE LIMITS
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory

    msg := sprintf("Container '%s' must define memory limits", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.cpu

    msg := sprintf("Container '%s' must define CPU limits", [container.name])
}

warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests.memory

    msg := sprintf("Container '%s' should define memory requests", [container.name])
}

# ==============================================================================
# REQUIRE: LIVENESS & READINESS PROBES
# ==============================================================================
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.livenessProbe

    msg := sprintf("Container '%s' should define livenessProbe", [container.name])
}

warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.readinessProbe

    msg := sprintf("Container '%s' should define readinessProbe", [container.name])
}

# ==============================================================================
# REQUIRE: IMAGE PULL POLICY
# ==============================================================================
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.imagePullPolicy != "Always"

    msg := sprintf("Container '%s' should use imagePullPolicy: Always", [container.name])
}

# ==============================================================================
# DENY: IMAGES WITHOUT DIGEST
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    image := container.image

    # Image must use digest (sha256:...) for immutability
    not contains(image, "@sha256:")

    msg := sprintf("Container '%s' must use image digest (e.g., image@sha256:...), not tags", [container.name])
}

# ==============================================================================
# REQUIRE: SERVICE ACCOUNT
# ==============================================================================
warn[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.serviceAccountName

    msg := "Deployment should specify a serviceAccountName (not 'default')"
}

deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.serviceAccountName == "default"

    msg := "Deployment must not use 'default' service account"
}

# ==============================================================================
# REQUIRE: POD SECURITY CONTEXT
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.fsGroup

    msg := "Pod securityContext should define fsGroup"
}

deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.seccompProfile

    msg := "Pod securityContext must define seccompProfile (type: RuntimeDefault)"
}

# ==============================================================================
# REQUIRE: REPLICAS
# ==============================================================================
warn[msg] {
    input.kind == "Deployment"
    replicas := input.spec.replicas
    replicas < 2

    msg := sprintf("Deployment has only %d replica(s). Recommend at least 2 for high availability.", [replicas])
}

# ==============================================================================
# DENY: LATEST TAG
# ==============================================================================
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    image := container.image

    endswith(image, ":latest")

    msg := sprintf("Container '%s' must not use ':latest' tag. Use specific version or digest.", [container.name])
}

# ==============================================================================
# REQUIRE: LABELS
# ==============================================================================
required_labels := {"app", "version"}

warn[msg] {
    input.kind == "Deployment"
    missing := required_labels - {label | input.metadata.labels[label]}
    count(missing) > 0

    msg := sprintf("Deployment is missing required labels: %v", [missing])
}

# ==============================================================================
# SERVICE POLICIES
# ==============================================================================
deny[msg] {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"

    # Production should use Ingress instead
    msg := "Service type LoadBalancer is not allowed. Use Ingress for external access."
}
