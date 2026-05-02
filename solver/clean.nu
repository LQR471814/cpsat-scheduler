let dirs: list<string> = [
	daemon_bin.build
	daemon_bin.dist
	daemon_bin.onefile-build
]
rm --recursive --force ...$dirs
