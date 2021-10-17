
## setup your own spcomp path.
SPC = spcomp
INCLUDE1 = -i./styx/include
INCLUDE2 = -i./styx

src = $(wildcard ./styx/*.sp) 
obj = $(patsubst ./styx/%.sp, ./styx_compiled/%.smx, $(src))
SRC_DIR = ./styx
OBJ_DIR = ./styx_compiled

$(OBJ_DIR)/%.smx: $(SRC_DIR)/%.sp
	$(SPC) $< -o $@ -O2 $(INCLUDE1) $(INCLUDE2) -v0

all:$(obj)

$(obj): |$(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

.PHONY: clean  
clean:
	rm -rf $(obj)
