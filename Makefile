# Reset implicit rules as if using -r
.SUFFIXES:
# Reset implicit variables as if using -R
$(foreach var,$(filter-out .% MAKE% SUFFIXES,$(.VARIABLES)),\
  $(if $(findstring $(origin $(var)),default),\
    $(if $(filter undefine,$(.FEATURES)),\
      $(eval undefine $(var)),\
      $(eval $(var)=))))

# Build options
BUILTINS=1
PRAGMA_FP_CONTRACT=0
SIMD=1
OPENMP=1
DEBUG=0
PROFILE=0
SAVE_ASM=0
WINDOWS=0

# VARIABLES
CFLAGS+=-std=c11 -pedantic
CFLAGS+=-g
WARN_FLAGS+=-Wall -Wextra -Winline -Wshadow
NO_WARN_FLAGS+=-w
ifeq ($(CC),)
CC=$(HOST)gcc
endif
ifeq ($(WINDRES),)
WINDRES=$(HOST)windres
endif
LIBS+=-ljpeg -lpng -lm -lz
OBJS+=jpeg2png.o utils.o jpeg.o png.o pngin.o box.o compute.o logger.o progressbar.o fp_exceptions.o gopt/gopt.o ooura/dct.o
HOST=
EXE=

# Detect the environment to set compiler and flags
ifneq ($(MSYSTEM),)
    ifeq ($(MSYSTEM),CLANG64)
        CC = clang
        BFLAGS += -fopenmp=libomp
        LIBS += -ljpeg -lpng -lm -lz -lpsapi
    else ifeq ($(MSYSTEM),CLANG32)
        CC = clang
        BFLAGS += -fopenmp=libomp
        LIBS += -ljpeg -lpng -lm -lz -lpsapi
    else ifeq ($(MSYSTEM),MINGW64)
        CC = x86_64-w64-mingw32-gcc
    else ifeq ($(MSYSTEM),MINGW32)
        CC = i686-w64-mingw32-gcc
        WINDRES = windres --target=pe-i386
    endif
endif

# Apply specific flags when CC is clang
ifeq ($(CC),clang)
    BFLAGS += -fopenmp=libomp
    LIBS += -ljpeg -lpng -lm -lz
endif

ifeq ($(BUILTINS),1)
CFLAGS+=-DBUILTIN_UNREACHABLE -DBUILTIN_ASSUME_ALIGNED -DATTRIBUTE_UNUSED
endif

ifeq ($(PRAGMA_FP_CONTRACT),1)
CFLAGS+=-DPRAGMA_FP_CONTRACT
else # not supported by gcc
CFLAGS+=-ffp-contract=off
endif

ifeq ($(SIMD),1)
CFLAGS+=-DUSE_SIMD
CFLAGS+=-msse2 -mfpmath=sse
endif

ifeq ($(OPENMP),1)
BFLAGS+=-fopenmp
endif

ifeq ($(DEBUG),1)
CFLAGS+=-Og -DDEBUG
else
CFLAGS+=-O3 -DNDEBUG
endif

ifeq ($(PROFILE),1)
BFLAGS+=-pg
endif

ifeq ($(WINDOWS),1)
    # Set HOST based on environment if not already set
    ifeq ($(HOST),)
        ifeq ($(shell uname -s),Linux)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        else ifeq ($(shell uname -s),Darwin)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        else ifeq ($(findstring MINGW,$(shell uname -s)),MINGW)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        endif
    endif

    EXE=.exe
    LDFLAGS+=-static -s
    CFLAGS+=-mstackrealign
    RES+=icon.rc.o

    # Set WINDRES based on environment and architecture
    ifeq ($(MSYSTEM),MINGW32)
        WINDRES = windres --target=pe-i386
    else ifeq ($(MSYSTEM),CLANG32)
        WINDRES = windres --target=pe-i386
    else ifeq ($(findstring MINGW,$(shell uname -s)),MINGW)
        ifeq ($(HOST),i686-w64-mingw32-)
            WINDRES = windres --target=pe-i386
        else
            WINDRES = windres
        endif
    else
        ifeq ($(HOST),i686-w64-mingw32-)
            WINDRES = $(HOST)windres --target=pe-i386
        else
            WINDRES = $(HOST)windres
        endif
    endif
else
    CFLAGS+=-D_POSIX_C_SOURCE=200112
endif


ifeq ($(SAVE_ASM),1)
CFLAGS+=-save-temps -masm=intel -fverbose-asm
endif

CFLAGS+=$(BFLAGS)
LDFLAGS+=$(BFLAGS)

# RULES
.PHONY: clean all install uninstall
all: jpeg2png$(EXE)

jpeg2png$(EXE): $(OBJS) $(RES) Makefile
	$(CC) $(OBJS) $(RES) -o $@ $(LDFLAGS) $(LIBS)

-include $(OBJS:.o=.d)

gopt/gopt.o: gopt/gopt.c gopt/gopt.h Makefile
	$(CC) $< -c -o $@ $(CFLAGS) $(NO_WARN_FLAGS)

%.o: %.c Makefile
	$(CC) -MP -MMD $< -c -o $@ $(CFLAGS) $(WARN_FLAGS)

%.rc.o: %.rc Makefile
	$(WINDRES) $< $@

clean:
	git clean -Xf

install: all
	install -Dm755 jpeg2png "$(DESTDIR)"/usr/bin/jpeg2png

uninstall:
	rm "$(DESTDIR)"/usr/bin/jpeg2png
