import logging
import json
from itertools import groupby

import tornado.web
import tornado.ioloop
import redis

LOG = logging.getLogger("tornado.application")
red_con = redis.StrictRedis(host="localhost", port=6379, db=0)

def squash(line, action=max):
    step = len(line) / 100
    if step <= 1:
        return line
    grouped_line = [list(v) for (i,v) in groupby(enumerate(line), lambda (i,v): i / step)]
    def _squasher(acc, value):
        i, v = value
        return [action(acc[0], v[0]), action(acc[1], v[1])]
    return [reduce(_squasher, g, [0, 0]) for g in grouped_line]

class MonHandler(tornado.web.RequestHandler):
    def get(self, action):
        last_n = self.get_query_argument("n", 500)
        action = action.strip()
        if not action:
            self.render("index.html")
        elif action == "pings.json":
            data = red_con.lrange("pings", 0, last_n)
            # LOG.warning(data)
            data = [json.loads(e) for e in data]
            line = [[e["at"], e["delay"]] for e in data]
            line = squash(line)
            self.write({"result": [line]})
        elif action == "cputemp.json":
            data = red_con.lrange("temp", 0, last_n)
            # LOG.warning(data)
            data = [json.loads(e) for e in data]
            line1 = [[e["at"], e["temp1"]] for e in data]
            line2 = [[e["at"], e["temp2"]] for e in data]
            line1 = squash(line1)
            self.write({"result": [line1, ]})
        else:
            raise tornado.web.HTTPError(500)


def main():
    logging.getLogger("tornado").setLevel(logging.INFO)
    app = tornado.web.Application([
        (r"/(.*)?", MonHandler)
    ],
        static_path="static",
        template_path="template",
        debug=True)
    app.listen(8080)
    tornado.ioloop.IOLoop.current().start()


if __name__ == "__main__":
    main()
