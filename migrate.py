import json
import redis

red_con = redis.StrictRedis(host="localhost", port=6379, db=0)


values = []
v = red_con.lpop("pings")
while v is not None:
    v = eval(v)
    v["at"] = int(v["at"])
    v = json.dumps(v)
    values.append(v)
    v = red_con.lpop("pings")

for v in reversed(values):
    red_con.lpush("pings", v)
