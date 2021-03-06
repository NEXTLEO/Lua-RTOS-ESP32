#
# This is a project Makefile. It is assumed the directory this Makefile resides in is a
# project subdirectory.
#

# Supported boards
define b
   WHITECAT-ESP32-N1
   WHITECAT-ESP32-N1-OTA
   WHITECAT-ESP32-N1-DEVKIT
   WHITECAT-ESP32-N1-DEVKIT-OTA
   ESP32-CORE-BOARD
   ESP32-CORE-BOARD-OTA
   ESP32-THING
   ESP32-THING-OTA
   GENERIC
   GENERIC-OTA
endef

# New line
define n


endef

# Use this esp-idf commit in build
CURRENT_IDF := 2e8441df9eb046b2436981dbaaa442b312f12101

# Project name
PROJECT_NAME := lua_rtos

# Get current config if is it missing
ifeq ("$(SDKCONFIG_DEFAULTS)","")
ifneq ("$(shell test -e .current_config && echo ex)","ex")
$(error $nLua RTOS need to know the default configuration for your board. First execute:$n$nmake SDKCONFIG_DEFAULTS=board defconfig$n$nboard:$n$b$n)
else
SDKCONFIG_DEFAULTS := $(shell cat .current_config)
ifneq ("$(shell test -e $(SDKCONFIG_DEFAULTS) && echo ex)","ex")
$(error $(SDKCONFIG_DEFAULTS) does not exists)
endif
endif
else
# Store config
ifneq ("$(shell test -e $(SDKCONFIG_DEFAULTS) && echo ex)","ex")
$(error $(SDKCONFIG_DEFAULTS) does not exists)
endif
$(shell echo $(SDKCONFIG_DEFAULTS) > .current_config)
endif

all_binaries: configure-idf-lua-rtos configure-idf-lua-rtos-tests defconfig

include $(IDF_PATH)/make/project.mk

clean: restore-idf

# Get patches files
LUA_RTOS_PATCHES := $(abspath $(wildcard components/lua_rtos/patches/*.patch))

#
# This part generates the esptool arguments required for erase the otadata region. This is required in case that
# an OTA firmware is build, so we want to update the factory partition when making "make flash".
#
$(shell $(IDF_PATH)/components/partition_table/gen_esp32part.py --verify $(PROJECT_PATH)/$(PARTITION_TABLE_CSV_NAME) $(PROJECT_PATH)/build/partitions.bin)

comma := ,

ifeq ("$(PARTITION_TABLE_CSV_NAME)","partitions-ota.csv")
OTA_PARTITION_INFO := $(shell $(IDF_PATH)/components/partition_table/gen_esp32part.py --quiet $(PROJECT_PATH)/build/partitions.bin | grep "otadata")

OTA_PARTITION_ADDR        := $(word 4, $(subst $(comma), , $(OTA_PARTITION_INFO)))
OTA_PARTITION_SIZE_INFO   := $(word 5, $(subst $(comma), , $(OTA_PARTITION_INFO)))
OTA_PARTITION_SIZE_UNITS  := $(word 1, $(subst M, M, $(subst K, K, $(word 5, $(subst $(comma), , $(OTA_PARTITION_INFO))))))
OTA_PARTITION_SIZE_UNIT   := $(word 2, $(subst M, M, $(subst K, K, $(word 5, $(subst $(comma), , $(OTA_PARTITION_INFO))))))

OTA_PARTITION_SIZE_FACTOR := 1
ifeq ($(OTA_PARTITION_SIZE_UNIT),K)
OTA_PARTITION_SIZE_FACTOR := 1024
endif

ifeq ($(OTA_PARTITION_SIZE_UNIT),M)
OTA_PARTITION_SIZE_FACTOR := 1048576
endif

OTA_PARTITION_SIZE := $(shell echo ${OTA_PARTITION_SIZE_UNITS}*${OTA_PARTITION_SIZE_FACTOR} | bc)

ESPTOOL_ERASE_OTA_ARGS := $(ESPTOOLPY) --chip esp32 --port $(ESPPORT) --baud $(ESPBAUD) erase_region $(OTA_PARTITION_ADDR) $(OTA_PARTITION_SIZE)
else
ESPTOOL_ERASE_OTA_ARGS :=
endif

#
# This part gets the information for the spiffs partition
#
SPIFFS_PARTITION_INFO := $(shell $(IDF_PATH)/components/partition_table/gen_esp32part.py --quiet $(PROJECT_PATH)/build/partitions.bin | grep "spiffs")

SPIFFS_BASE_ADDR   := $(word 4, $(subst $(comma), , $(SPIFFS_PARTITION_INFO)))
SPIFFS_SIZE_INFO   := $(word 5, $(subst $(comma), , $(SPIFFS_PARTITION_INFO)))
SPIFFS_SIZE_UNITS  := $(word 1, $(subst M, M, $(subst K, K, $(word 5, $(subst $(comma), , $(SPIFFS_PARTITION_INFO))))))
SPIFFS_SIZE_UNIT   := $(word 2, $(subst M, M, $(subst K, K, $(word 5, $(subst $(comma), , $(SPIFFS_PARTITION_INFO))))))

SPIFFS_SIZE_FACTOR := 1
ifeq ($(SPIFFS_SIZE_UNIT),K)
SPIFFS_SIZE_FACTOR := 1024
endif

ifeq ($(SPIFFS_SIZE_UNIT),M)
SPIFFS_SIZE_FACTOR := 1048576
endif

ifeq ("foo$(SPIFFS_SIZE_UNIT)", "foo")
SPIFFS_SIZE_UNITS := 512
SPIFFS_SIZE_FACTOR := 1024
endif

SPIFFS_SIZE := $(shell echo ${SPIFFS_SIZE_UNITS}*${SPIFFS_SIZE_FACTOR} | bc)

#
# Make rules
#
flash: erase-ota-data

erase-ota-data: 
	$(ESPTOOL_ERASE_OTA_ARGS)
	
configure-idf-lua-rtos-tests:
	@echo "Configure esp-idf for Lua RTOS tests ..."
	@touch $(PROJECT_PATH)/components/lua_rtos/sys/sys_init.c
	@touch $(PROJECT_PATH)/components/lua_rtos/Lua/src/lbaselib.c
ifneq ("$(shell test -e  $(IDF_PATH)/components/lua_rtos && echo ex)","ex")
	@ln -s $(PROJECT_PATH)/main/test/lua_rtos $(IDF_PATH)/components/lua_rtos 2> /dev/null
endif

configure-idf-lua-rtos: $(LUA_RTOS_PATCHES)
ifneq ("$(shell test -e $(IDF_PATH)/lua_rtos_patches && echo ex)","ex")
	@echo "Reverting previous Lua RTOS esp-idf patches ..."
	@cd $(IDF_PATH) && git checkout .
	@cd $(IDF_PATH) && git checkout $(CURRENT_IDF)
	@echo "Applying Lua RTOS esp-idf patches ..."
	@cd $(IDF_PATH) && git apply --whitespace=warn $^
	@touch $(IDF_PATH)/lua_rtos_patches
endif

restore-idf:
	@echo "Reverting previous Lua RTOS esp-idf patches ..."
ifeq ("$(shell test -e $(IDF_PATH)/lua_rtos_patches && echo ex)","ex")
	@cd $(IDF_PATH) && git checkout .
	@cd $(IDF_PATH) && git checkout master
	@rm $(IDF_PATH)/lua_rtos_patches
	@make SDKCONFIG_DEFAULTS=$(SDKCONFIG_DEFAULTS) defconfig
endif
		
flash-args:
	@echo $(subst --port $(ESPPORT),, \
			$(subst python /components/esptool_py/esptool/esptool.py,, \
				$(subst $(IDF_PATH),, $(ESPTOOLPY_WRITE_FLASH))\
			)\
	 	  ) \
	 $(subst /build/, , $(subst /build/bootloader/,, $(subst $(PROJECT_PATH), , $(ESPTOOL_ALL_FLASH_ARGS))))