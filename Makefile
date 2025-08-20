# ======================
#  Paramètres généraux
# ======================
CXX              := g++
CXXFLAGS         := -std=c++17 -Wall -g -O0 -static
INCLUDE_DIRS     := -Iinclude \
                    -Ilib/rplidar_sdk/sdk/include \
                    -Ilib/rplidar_sdk/sdk/src \
                    -I../librairie-commune/common/include \
                    -I../librairie-commune/master/include
LDFLAGS          := -Llib/rplidar_sdk/output/Linux/Release
LDLIBS           := -pthread -li2c -lrt -lsl_lidar_sdk

# Git commit hash découpé en 4 parties (pour versioning)
GIT_SHA := $(shell git -C ../librairie-commune rev-parse --short HEAD)
CXXFLAGS += $(foreach i,1 2 3 4, -DGIT_COMMIT_SHA_PART$(i)=0x$(shell echo $(GIT_SHA) | cut -c$$(($(i)*2-1))-$(($(i)*2))))

# ======================
#  Répertoires & fichiers
# ======================
BINDIR      := bin
ARMBINDIR   := arm_bin
OBJDIR      := obj
SRCDIR      := src
SRCDIR_LIB  := ../librairie-commune/master/src
TARGET      := $(BINDIR)/programCDFR
ARM_TARGET  := $(ARMBINDIR)/programCDFR

SRC         := $(shell find $(SRCDIR) -name "*.cpp")
SRC_LIB     := $(shell find $(SRCDIR_LIB) -name "*.cpp")

OBJ_NATIVE  := $(patsubst $(SRCDIR)/%.cpp,$(OBJDIR)/native/%.o,$(SRC)) \
               $(patsubst $(SRCDIR_LIB)/%.cpp,$(OBJDIR)/native_lib/%.o,$(SRC_LIB))

OBJ_ARM     := $(patsubst $(SRCDIR)/%.cpp,$(OBJDIR)/arm/%.o,$(SRC)) \
               $(patsubst $(SRCDIR_LIB)/%.cpp,$(OBJDIR)/arm_lib/%.o,$(SRC_LIB))

DEPENDS     := $(OBJ_NATIVE:.o=.d) $(OBJ_ARM:.o=.d)


# ======================
#  Compilation native
# ======================
all: check lidar $(TARGET)
	@echo "Compilation native terminée. Lancez : (cd $(BINDIR) && sudo ./programCDFR)"

$(TARGET): $(OBJ_NATIVE)
	@mkdir -p $(BINDIR)
	@echo "[LINK] $@"
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS) $(LDLIBS) -Llib/x86_64-linux-gnu


# ======================
#  Compilation ARM (cross)
# ======================
CROSS_COMPILE   := aarch64-linux-gnu
ARM_CXX         := $(CROSS_COMPILE)-g++

arm: check lidar-arm $(ARM_TARGET)
	@echo "Compilation ARM terminée."

$(ARM_TARGET): $(OBJ_ARM)
	@mkdir -p $(ARMBINDIR)
	@echo "[ARM-LINK] $@"
	$(ARM_CXX) $(CXXFLAGS) -D__CROSS_COMPILE_ARM__ -o $@ $^ $(LDFLAGS) $(LDLIBS) -Llib/aarch64-linux-gnu


# ======================
#  Règles objets (génériques)
# ======================
$(OBJDIR)/native/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[CXX] $@"
	$(CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -MMD -MP -c $< -o $@

$(OBJDIR)/native_lib/%.o: $(SRCDIR_LIB)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[CXX] $@"
	$(CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -MMD -MP -c $< -o $@

$(OBJDIR)/arm/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[ARM-CXX] $@"
	$(ARM_CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -D__CROSS_COMPILE_ARM__ -MMD -MP -c $< -o $@

$(OBJDIR)/arm_lib/%.o: $(SRCDIR_LIB)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[ARM-CXX] $@"
	$(ARM_CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -D__CROSS_COMPILE_ARM__ -MMD -MP -c $< -o $@


# ======================
#  Lidar SDK
# ======================
lidar:
	@echo "[MAKE] lidarLib (x86_64)"
	$(MAKE) -C lib/rplidar_sdk

lidar-arm:
	@echo "[MAKE] lidarLib (ARM64)"
	cd lib/rplidar_sdk && CROSS_COMPILE_PREFIX=$(CROSS_COMPILE) ./cross_compile.sh


# ======================
#  Déploiement Raspberry Pi
# ======================
PI_USER := robotronik
PI_HOST := raspitronik.local
PI_DIR  := /home/$(PI_USER)/CDFR2025

install: arm
	@echo "[DEPLOY] vers Raspberry Pi..."
	ssh $(PI_USER)@$(PI_HOST) 'mkdir -p $(PI_DIR)'
	rsync -av --progress ./$(ARMBINDIR) $(PI_USER)@$(PI_HOST):$(PI_DIR)

install-run: install
	rsync -av ./autoRunInstaller.sh $(PI_USER)@$(PI_HOST):$(PI_DIR)/$(ARMBINDIR)
	ssh $(PI_USER)@$(PI_HOST) '(cd $(PI_DIR)/$(ARMBINDIR) && sudo ./autoRunInstaller.sh --install programCDFR)'

uninstall:
	rsync -av ./autoRunInstaller.sh $(PI_USER)@$(PI_HOST):$(PI_DIR)/$(ARMBINDIR)
	ssh $(PI_USER)@$(PI_HOST) '(cd $(PI_DIR)/$(ARMBINDIR) && sudo ./autoRunInstaller.sh --uninstall programCDFR)'


# ======================
#  Vérifs & Nettoyage
# ======================
check:
	@if [ ! -d "$(SRCDIR_LIB)" ]; then \
	  echo "Erreur: librairie-commune manquante ($(SRCDIR_LIB))"; \
	  echo "Clonez https://github.com/Arviscube/CDFR"; \
	  exit 1; \
	fi

clean:
	@echo "[CLEAN] objets/binaires"
	rm -rf $(OBJDIR) $(BINDIR) $(ARMBINDIR)

clean-lidar:
	@echo "[CLEAN] lidarLib"
	$(MAKE) -C lib/rplidar_sdk clean

clean-all: clean clean-lidar


# Inclusion des dépendances générées automatiquement
-include $(DEPENDS)
