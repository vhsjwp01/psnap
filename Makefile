PLATFORM	= $(shell uname -s)

overlay:
	./overlay.sh

prep:
	./prep.sh

install:
	case "${PLATFORM}" in                                             \
	    Darwin|Linux)                                                 \
	        make prep                                              && \
	        make overlay                                           && \
		systemctl enable rc-local-psnap.service                   \
	    ;;                                                            \
	    *)                                                            \
	        echo "Unknown (and unsupported) platform: ${PLATFORM}"    \
	    ;;                                                            \
	esac
