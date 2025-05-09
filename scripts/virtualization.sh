#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

echo "=== GPU Passthrough Compatibility Check ==="
echo "This script checks CPU virtualization, IOMMU support, and GPU IOMMU group isolation."
echo "Note: 100% compatibility cannot be guaranteed due to BIOS/firmware or hardware-specific issues."
echo ""

check_cpu_virt() {
    echo "Checking CPU virtualization support..."
    if lscpu | grep -q "Virtualization:.*VT-x\|AMD-V"; then
        echo "✓ CPU supports virtualization (VT-x/AMD-V detected)."
    else
        echo "✗ CPU does not support virtualization. Passthrough is not possible."
        exit 1
    fi

    if dmesg | grep -q "DMAR:.*Intel.*IOMMU"; then
        echo "✓ Intel VT-d (IOMMU) detected."
    elif dmesg | grep -q "AMD-Vi:.*IOMMU"; then
        echo "✓ AMD-Vi (IOMMU) detected."
    else
        echo "✗ No IOMMU support detected in dmesg. Check BIOS for VT-d/AMD-Vi enablement."
        echo "  Run 'dmesg | grep IOMMU' for details."
        exit 1
    fi
}

check_iommu_enabled() {
    echo "Checking if IOMMU is enabled..."
    if [ -d /sys/kernel/iommu_groups ]; then
        groups=$(ls /sys/kernel/iommu_groups | wc -l)
        if [ "$groups" -gt 0 ]; then
            echo "✓ IOMMU is enabled ($groups groups found)."
        else
            echo "✗ IOMMU enabled but no groups found. Check kernel parameters (intel_iommu=on/amd_iommu=on)."
            exit 1
        fi
    else
        echo "✗ IOMMU not enabled. Add 'intel_iommu=on' (Intel) or 'amd_iommu=on' (AMD) to kernel parameters."
        echo "  Edit /etc/default/grub, add to GRUB_CMDLINE_LINUX_DEFAULT, then run 'update-grub'."
        exit 1
    fi
}

check_gpu_iommu_groups() {
    echo "Checking GPU IOMMU group isolation..."
    echo "Listing devices in IOMMU groups (focusing on GPU-related devices):"
    echo ""

    gpu_found=false
    isolation_issues=false
    shopt -s nullglob
    for group in /sys/kernel/iommu_groups/*; do
        group_num=${group##*/}
        devices=""
        gpu_in_group=false
        for device in $group/devices/*; do
            dev_id=${device##*/}
            dev_info=$(lspci -nns "$dev_id" 2>/dev/null)
            if [[ "$dev_info" =~ "VGA" || "$dev_info" =~ "Audio" || "$dev_info" =~ "Display" ]]; then
                gpu_in_group=true
                gpu_found=true
            fi
            devices+="$dev_info\n"
        done
        if [ "$gpu_in_group" = true ]; then
            echo "IOMMU Group $group_num:"
            echo -e "$devices" | while IFS= read -r line; do
                echo "  $line"
            done
            dev_count=$(echo -e "$devices" | grep -c .)
            if [ "$dev_count" -gt 2 ]; then
                echo "⚠ Warning: Group contains $dev_count devices. GPU may not be isolated."
                echo "  Consider ACS override patch or different PCIe slot for isolation."
                isolation_issues=true
            else
                echo "✓ Group appears isolated ($dev_count devices)."
            fi
            echo ""
        fi
    done

    if [ "$gpu_found" = false ]; then
        echo "✗ No GPU or related devices (VGA, Audio, Display) found in IOMMU groups."
        echo "  Ensure GPU is detected by 'lspci' and IOMMU is properly configured."
        exit 1
    fi

    if [ "$isolation_issues" = true ]; then
        echo "⚠ Some IOMMU groups may not be isolated. Passthrough may work with ACS patch, but issues could arise."
    else
        echo "✓ All detected GPU-related IOMMU groups appear isolated."
    fi
}

check_common_issues() {
    echo "Checking for common passthrough issues..."
    
    if ! lsmod | grep -q "vfio_pci"; then
        echo "⚠ VFIO-PCI module not loaded. Ensure 'vfio-pci' is enabled."
        echo "  Run 'modprobe vfio-pci' to test, or add to /etc/modules-load.d/."
    else
        echo "✓ VFIO-PCI module available."
    fi

    if lspci | grep -i nvidia; then
        echo "⚠ Nvidia GPU detected. May require VBIOS patching to avoid error 43 in Windows VMs."
        echo "  Dump VBIOS and edit with hex editor if needed."
    fi
}

final_recommendations() {
    echo "=== Summary ==="
    echo "Based on the checks:"
    echo "- CPU virtualization and IOMMU support: $(if dmesg | grep -q 'DMAR\|AMD-Vi'; then echo '✓ Pass'; else echo '✗ Fail'; fi)"
    echo "- IOMMU enabled: $(if [ -d /sys/kernel/iommu_groups ]; then echo '✓ Pass'; else echo '✗ Fail'; fi)"
    echo "- GPU IOMMU group isolation: $(if [ "$isolation_issues" = false ] && [ "$gpu_found" = true ]; then echo '✓ Pass'; else echo '⚠ Warning'; fi)"
    echo ""
    echo "Next steps:"
    echo "- Verify BIOS settings (VT-d/AMD-Vi enabled)."
    echo "- Check community feedback for your specific hardware (CPU: $(lscpu | grep 'Model name' | cut -d: -f2-), GPU: $(lspci | grep 'VGA\|Display' | cut -d: -f3-))."
    echo "- If isolation issues persist, research ACS override or PCIe slot adjustments."
    echo "- For Nvidia GPUs, prepare to patch VBIOS if using Windows VMs."
    echo ""
    echo "For detailed setup, refer to:"
    echo "- Arch Linux Wiki: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF"
    echo "- r/VFIO Community: https://www.reddit.com/r/VFIO/"
}

check_cpu_virt
echo ""
check_iommu_enabled
echo ""
check_gpu_iommu_groups
echo ""
check_common_issues
echo ""
final_recommendations

exit 0
