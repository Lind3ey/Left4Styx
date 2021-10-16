
## setup your own spcomp path.
SPC = "../../L4D2-Competitive-Rework/addons/sourcemod/scripting/spcomp"
INCLUDE1 = -i./styx/include
INCLUDE2 = -i./styx

src = $(wildcard ./styx/*.sp)  
obj = $(patsubst ./styx/%.sp, ./styx_compiled/%.smx, $(src))

all:$(obj)

$(obj): $(src) 
	$(SPC) $< -o $@ -O2 $(INCLUDE1) $(INCLUDE2) -v0

.PHONY: clean  
clean:
	rm -rf $(obj) $(target)
