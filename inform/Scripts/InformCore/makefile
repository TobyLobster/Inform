# The top-level makefile for the 'Inform Core' folder, for the macOS app.
# Copy it into 'Inform Core', beside the 'inform' repository, along with
# make-integration-settings.mk: see documentation/building_inform.md in
# InformApp. The app's build runs 'make all' here, or 'make force' on a
# clean build.

.PHONY: all
all:
	cd inform; make
	cd inform; make integration

.PHONY: force
force:
	cd inform; make force
	cd inform; make forceintegration
