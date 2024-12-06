ifeq ($(origin VERSION), undefined)
# avoid ?= lazily evaluating version.sh (and thus rerunning the shell command several times)
VERSION := $(shell ./version.sh)
endif

TELE ?= $(shell which tele)
GRAVITY ?= $(shell which gravity)

REPOSITORY := gravitational.io
NAME := cluster-ssl-app
OPS_URL ?=
# gravity uses `/var/lib/gravity` directory if state-dir is empty
STATEDIR ?= state

EXTRA_GRAVITY_OPTIONS ?=
# add state directory to the commands if STATEDIR variable not empty
ifneq ($(STATEDIR),)
	EXTRA_GRAVITY_OPTIONS +=  --state-dir=$(STATEDIR)
endif

CONTAINERS := cluster-ssl-hook:$(VERSION)

IMPORT_IMAGE_FLAGS := --set-image=cluster-ssl-hook:$(VERSION)

FILE_LIST := $(shell ls -1A)
WHITELISTED_RESOURCE_NAMES := resources

IMPORT_OPTIONS := --vendor \
		--ops-url=$(OPS_URL) \
		--repository=$(REPOSITORY) \
		--name=$(NAME) \
		--version=$(VERSION) \
		--glob=**/*.yaml \
		$(foreach resource, $(filter-out $(WHITELISTED_RESOURCE_NAMES), $(FILE_LIST)), --exclude="$(resource)") \
		$(IMPORT_IMAGE_FLAGS)

BUILD_DIR := build
BINARIES_DIR := bin
TARBALL := $(BUILD_DIR)/application.tar

$(STATEDIR):
	mkdir -p $(STATEDIR)

.PHONY: all
all: clean images

.PHONY: what-version
what-version:
	@echo $(VERSION)

.PHONY: images
images:
	cd $(PWD)/images &&	$(MAKE) VERSION=$(VERSION) && cd $(PWD)

.PHONY: build-app
build-app: images

.PHONY: import
import: images | $(STATEDIR)
	-$(GRAVITY) app delete --ops-url=$(OPS_URL) $(REPOSITORY)/$(NAME):$(VERSION) --force $(EXTRA_GRAVITY_OPTIONS)
	$(GRAVITY) app import $(IMPORT_OPTIONS) $(EXTRA_GRAVITY_OPTIONS) .

.PHONY: export
export: $(TARBALL)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TARBALL): import | $(BUILD_DIR)
	$(GRAVITY) package export --ops-url=$(OPS_URL) $(REPOSITORY)/$(NAME):$(VERSION) $(TARBALL) $(EXTRA_GRAVITY_OPTIONS)

$(BINARIES_DIR):
	mkdir -p $(BINARIES_DIR)

.PHONY: download-binaries
download-binaries: $(BINARIES_DIR)
	for name in gravity tele; \
	do \
		aws s3 cp s3://gravity-installers/gravity/release/$(GRAVITY_VERSION)/linux-amd64/$$name $(BINARIES_DIR)/$$name; \
		chmod +x $(BINARIES_DIR)/$$name; \
	done

.PHONY: upload-application
upload-application: $(TARBALL)
	aws s3 cp $(TARBALL) s3://onprem-standalone-installers/cluster-ssl-app/cluster-ssl-app-$(VERSION).tar

.PHONY: clean
clean: clean-state-dir
	rm -rf $(BUILD_DIR)

clean-state-dir:
	-rm -rf $(STATEDIR)
