# Matrix WhatsApp Decommission

This Application is intentionally kept with an empty desired state for the first decommission phase.

ArgoCD should prune the former bridge Deployment, Service, ConfigMap, and CloudNativePG cluster from the `matrix` namespace. After ArgoCD confirms the child app has no managed resources left, remove `../../base/matrix-whatsapp`, `argocd/base/matrix-whatsapp/`, and this directory in a follow-up GitOps change.
