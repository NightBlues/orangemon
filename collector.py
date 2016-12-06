import logging
import socket
import json
from time import sleep, time

import ping
import redis

LOG = logging.getLogger(__name__)
red_con = redis.StrictRedis(host="localhost", port=6379, db=0)


def get_delay(server):
    """Return timeout (int) in microseconds.

    If timedout or error - 1 second is returned."""
    try:
        delay = ping.do_one(server, 0.999999, 64)
        # if timed out
        if delay is None:
            delay = 0.009999
        delay = int(delay * 1000 * 1000)
    except socket.error:
        delay = 9999
    return delay


def main():
    logging.basicConfig(level=logging.INFO,
        format="%(asctime)s %(levelname)s: %(message)s")
    while True:
        LOG.info("Collecting stats for pings...")
        at = int(time())
        delay = get_delay("yandex.ru")
        with open("/sys/class/hwmon/hwmon1/temp1_input") as fp:
            temp1 = int(fp.read())
        with open("/sys/class/hwmon/hwmon2/temp1_input") as fp:
            temp2 = int(fp.read())
        LOG.info({"at": at, "delay": delay})
        LOG.info({"at": at, "temp1": temp1, "temp2": temp2})
        red_con.lpush("pings", json.dumps({"at": at, "delay": delay}))
        red_con.lpush("temp", json.dumps({"at": at, "temp1": temp1, "temp2": temp2}))
        sleep(60)

if __name__ == "__main__":
    main()
