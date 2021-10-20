
## setup your own spcomp path.
SPC = spcomp
INCLUDE = -i./styx -i./styx/include

src = $(wildcard ./styx/*.sp) 
obj = $(patsubst ./styx/%.sp, ./compiled/%.smx, $(src))
SRC_DIR = ./styx
OBJ_DIR = ./compiled

$(OBJ_DIR)/%.smx: $(SRC_DIR)/%.sp
	$(SPC) $< -o $@ -O2 -v0 $(INCLUDE)

all:$(obj)

$(obj): |$(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

.PHONY: clean  
clean:
	rm -rf $(obj)
