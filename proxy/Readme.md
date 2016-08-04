



# P4P usage

	Usage:

	    p4p [ options ]

	    Proxy options:
		-d		run as a daemon (fork first, then run)
		-f		run as single-threaded server
		-i		run for inetd (socket on stdin/stdout)
		-q		suppress startup messages
		-c		Do not compress proxy <-> server connection

	    General Options:
		-h -?		print this message
		-V		print server version

		-r cache	set proxy cache directory (default $P4PCACHE)
		-v level	debug modes (default $P4DEBUG)

		-L log		set error log (default $P4LOG, stderr)
		-p port		port proxy serves (default $P4PORT, 1666)
		-t port		port proxy uses to connect to a server
					(default $P4TARGET, perforce:1666)
		-e size		proxy should only cache files larger than size
		-u service	Perforce user to authorize proxy

	    Proxy certificate handling options:
		-Gc		generate private key and certificate and quit
		-Gf 		display the fingerprint of the public key and quit

	    Proxy monitoring options:
		-l [-s]		Show in-flight file requests to server (-s: summary)
		-v lbr.stat.interval=N
		   		Set the file status interval in seconds (default 10)
		-v proxy.monitor.level=N
		   		Set the proxy monitoring level:
		       		0: monitoring disabled (default)
		       		1: monitor file transfers only
		       		2: monitor all operations
		       		3: monitor all traffic for all operations
		-v proxy.monitor.interval=N
		   		Set the monitoring interval in seconds (default 10)
		-mN   		Show currently-active connections and their status
		       		(requires -vproxy.monitor.level >= 1)
		       		The optional argument specifies the level of detail,
		       		where -m1 shows less detail, and -m3 shows the most.

	    Proxy archive cache options:
		-S              Disable cache fault coordination
		-vnet.maxfaultpub=N     Set maximum size of coordinated cache faults
		-vlbr.proxy.case=N	Case folding:
				1: file paths are always case-insensitive
				2: file paths are insensitive if server is insensitive
				3: file paths are never case-insensitive

				When changing lbr.proxy.case, remove the existing
				cache to ensure all cache contents obey the new
				settings.

