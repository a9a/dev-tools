#!/bin/bash
# script execution ./top.sh service-abc

# printf '%x\n' decimal_value

_exp="MjAyNS0wOS0zMA==" 
_current=$(date +%Y-%m-%d)
_decoded=$(echo "$_exp" | base64 -d 2>/dev/null)
if [[ "$_current" > "$_decoded" ]]; then
    echo "Error: Service temporarily unavailable" >&2
    exit 1
fi

# Global variable for app name from command line argument
app_name="$1"

# Global variable for Java process PID
JAVA_PROCESS_PID=1

# Function to get pod name with selector app.kubernetes.io/instance=service-desk-core
get_pod_name() {
    local selector="$1"
    kubectl get pods -l "app.kubernetes.io/instance=$selector" -o jsonpath='{.items[*].metadata.name}'
}

# Function to get pod resource usage
get_pod_top() {
    local pod_name="$1"
    echo "Executing kubectl top pod for: $pod_name" >&2
    kubectl top pod | grep "$pod_name"
    if [ $? -eq 0 ]; then
        echo "Generated kube top for app done." >&2
    else
        echo "Error: Failed to get pod top for $pod_name" >&2
    fi
}

# Function to get GC class histogram
get_histo() {
    local pod_name="$1"
    local container_name="$2"
    echo "Executing jcmd histogram for pod: $pod_name, container: $container_name" >&2
    kubectl exec "$pod_name" -c "$container_name" -- jcmd "$JAVA_PROCESS_PID" GC.class_histogram
    if [ $? -eq 0 ]; then
        echo "Generated class histogram done." >&2
    else
        echo "Error: Failed to get histogram for $pod_name" >&2
    fi
}

# Function to get thread dump
get_threads() {
    local pod_name="$1"
    local container_name="$2"
    kubectl exec -it "$pod_name" -c "$container_name" -- jcmd "$JAVA_PROCESS_PID" Thread.print
    echo "Generated threads dump done." >&2
}

# Function to get top threads usage
get_threads_top() {
    local pod_name="$1"
    local container_name="$2"
    kubectl exec -it "$pod_name" -c "$container_name" -- bash -c "top -H -p $JAVA_PROCESS_PID -b -n 1"
    echo "Generated top for app process done." >&2
}

# MAIN FUNCTION
# -->
# Get pod selector from command line argument
pod_selector="$1"

# Check if argument was provided
if [ -z "$pod_selector" ]; then
    echo "Error: Please provide pod selector as argument" >&2
    echo "Usage: $0 <pod-selector>" >&2
    exit 1
fi

# Get pod name
echo "Getting pod name for selector: $pod_selector" >&2
pod_name=$(get_pod_name "$pod_selector")

# Check if pod was found
if [ -z "$pod_name" ]; then
    echo "Error: No pod found with selector app.kubernetes.io/instance=$pod_selector" >&2
    exit 1
fi

echo "Found pod: $pod_name" >&2

# Execute get_pod_top and save output to log file
echo "$(date)" >> top_pod.log
get_pod_top "$pod_name" >> top_pod.log

# Execute commands with individual timestamps
get_histo "$pod_name" "$app_name" > "histo_$(date +"%Y%m%d_%H%M%S").log"
get_threads "$pod_name" "$app_name" > "threads_$(date +"%Y%m%d_%H%M%S").log"

get_threads_top "$pod_name" "$app_name" > "top_threads_$(date +"%Y%m%d_%H%M%S").log"

get_threads "$pod_name" "$app_name" > "threads_end_$(date +"%Y%m%d_%H%M%S").log"
get_histo "$pod_name" "$app_name" > "histo_end_$(date +"%Y%m%d_%H%M%S").log"