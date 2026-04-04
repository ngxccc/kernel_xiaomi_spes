# 1. Target object files based on Kernel configs
obj-$(CONFIG_FUELGAUGE_MAX77729)    += max77729_fuelgauge.o
obj-$(CONFIG_CHARGER_MAX77729)      += max77729_charger.o

# 2. HEADER INCLUDE PATHS (Crucial for resolving 'file not found' errors)
# Using -I$(srctree)/... ensures the compiler finds .h files safely,
# even during out-of-tree builds (e.g., when compiling into an 'out' dir).
ccflags-y += -I$(srctree)/drivers/power/supply/battery_secret
ccflags-y += -I$(srctree)/drivers/power/supply/maxim
ccflags-y += -I$(srctree)/include/linux/mfd

# 3. Auxiliary flags for fast charging and specific hardware configurations
# Define these macros to enable corresponding #ifdef logic in the C source files.
ccflags-y += -DCONFIG_MAXIM_SM5602_FG
ccflags-y += -DCONFIG_MAX77729_CHARGER

# 4. Safely append format warnings to compiler flags
ccflags-y += -Wformat

# 🐛 DEBUGGING: Uncomment the line below to enable verbose charging logs in dmesg
# ccflags-y += -DDEBUG
