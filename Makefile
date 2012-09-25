.PHONY: install uninstall clean

install:
	install --mode=755 --directory /etc/yabs
	install --mode=644 repo.list /etc/yabs
	install --mode=755 yabs.sh /usr/sbin/yabs
	install --mode=755 yabs-crontask.sh /usr/bin/yabs-crontask
	install --mode=644 crontask /etc/cron.d/yabs
	ln --force --symbolic --no-dereference \
		/var/lib/yabs/logs /var/log/yabs

uninstall:
	rm --recursive --force \
		/etc/yabs \
		/etc/cron.d/yabs \
		/usr/bin/yabs-crontask \
		/usr/sbin/yabs \
		/var/lib/yabs

clean:
	find . -name '*~' -delete

