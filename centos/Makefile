.PHONY: install uninstall clean

install:
	install --mode=755 yabs.sh /usr/sbin/yabs
	install --mode=755 yabs-crontask.sh /usr/sbin/yabs-crontask
	install --mode=644 crontask /etc/cron.d/yabs
	ln --force --symbolic --no-dereference \
		/var/lib/yabs/logs /var/log/yabs

uninstall:
	rm --recursive --force \
		/etc/cron.d/yabs \
		/usr/sbin/yabs-crontask \
		/usr/sbin/yabs \
		/var/lib/yabs \
		/var/log/yabs

clean:
	find . -name '*~' -delete

