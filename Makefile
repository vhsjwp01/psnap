PLATFORM	= $(shell uname -s)

overlay:
	./overlay.sh

prep:
	./prep.sh

install:
	case "${PLATFORM}" in                                             \
	    Darwin|Linux)                                                 \
	        make prep                                              && \
	        make overlay                                              \
	    ;;                                                            \
	    *)                                                            \
	        echo "Unknown (and unsupported) platform: ${PLATFORM}"    \
	    ;;                                                            \
	esac
