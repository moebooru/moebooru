#!/usr/bin/python2.6
import os, sqlite3
from pygooglechart import SimpleLineChart, XYLineChart, Axis

db = sqlite3.connect("/tmp/moe-data-traffic.db", isolation_level=None)
period = 900
def get_times():
	cursor = db.cursor()
	cursor.execute("SELECT DISTINCT time FROM bandwidth ORDER BY time ASC")
	prev = None
	# Don't yield the most recent time; it's not finished yet.
	for time in cursor.fetchall():
		if prev is not None:
			yield prev
		prev = time[0]

def get_total_bandwidth(time):
	cursor = db.cursor()
	cursor.execute("SELECT sum(bytes) FROM bandwidth_by_type WHERE time = %i" % time)
	return cursor.fetchone()[0]

def get_bandwidth_by_type(category, time):
	cursor = db.cursor()
	cursor.execute("SELECT COALESCE(sum(bytes), 0) FROM bandwidth_by_type WHERE category = %i AND time = %i GROUP BY category ORDER BY time, category ASC" % (category, time))
	row = cursor.fetchone()
	if row is not None:
		return row[0]
	else:
		return 0

def get_top_24h_ips(limit):
	cursor = db.cursor()
	cursor.execute("SELECT ip, sum(bytes) FROM bandwidth GROUP BY ip ORDER BY sum(bytes) DESC LIMIT %i" % (limit, ))
	for ip, bytes in cursor.fetchall():
		yield ip, bytes

def get_ip_bandwidth(ip, time):
	cursor = db.cursor()
	cursor.execute("SELECT sum(bytes) FROM bandwidth WHERE ip = %i AND time = %i" % (ip, time))
	return cursor.fetchone()[0] or 0

def get_top_users(time, limit):
	cursor = db.cursor()
	cursor.execute("SELECT ip, sum(bytes) FROM bandwidth WHERE time = %i GROUP BY ip, time ORDER BY time, sum(bytes) DESC LIMIT %i" % (time, limit))
	for ip, bytes in cursor.fetchall():
		yield ip, bytes

category_types = [
	(0, "808080", "other"),
	(1, "80FF80", "samples"),
	(2, "008080", "jpegs"),
	(3, "800080", "pngs"),
	(11, "8000FF", "zips"),
	(12, "0080FF", "jpeg zips"),
	(13, "8080FF", "png zips"),
]
def get_category_idx(category_id):
	for idx in range(0, len(category_types)):
		if category_types[idx][0] == category_id:
			return idx
	assert False, "invalid category_id %i" % category_id

def get_category_for_id(category_id):
	return [cat for cat in category_types if cat[0] == category_id][0]

def make_category_graph():
	data = []
	times = [t for t in get_times()]
	for i in range(0, len(category_types)):
		data.append([])

	x_axis = []
	for time in times:
		x_axis.append(time)
		x_axis.append(time+period)

		total = 0
		for idx in range(0, len(category_types)):
			category_id = category_types[idx][0]
			bytes = get_bandwidth_by_type(category_id, time)
			#speed = (bandwidth / period) / 1024
			speed = bytes / period
			total += speed
			data[idx].append(total)
			# print "#%i: time: %i, ip %i, %i bytes" % (idx, time, ip, bandwidth)

	for idx in range(0, len(data)):
		data[idx] = repeat_once(data[idx])

	chart = make_graph(x_axis, data, color_vertically=False)
	chart.add_fill_range("000000", 0, 1) # empty
	for idx, cat in enumerate(reversed(category_types)):
		chart.add_fill_range(cat[1], idx+1, idx+2)
	return chart

def make_bandwidth_graph():
	pass

def repeat_once(iter):
	ret = []
	
	for i in iter:
		ret.append(i)
		ret.append(i)
	return ret

#def make_top_user_graph(top_users_to_graph):
#	data = []
#	times = [t for t in get_times()]
#	for i in range(0, top_users_to_graph):
#		data.append([0] * len(times))
#
#	x_axis = []
#	for time_idx, time in enumerate(times):
#		x_axis.append(time)
#		x_axis.append(time+period)
#
#		total = 0
#		for idx, (ip, bytes) in enumerate(get_top_users(time, top_users_to_graph)):
#			#speed = (bandwidth / period) / 1024
#			speed = bytes / period
#			total += speed
#			data[idx][time_idx]=total
#			# print "#%i: time: %i, ip %i, %i bytes" % (idx, time, ip, bandwidth)
#	for idx in range(0, len(data)):
#		data[idx] = repeat_once(data[idx])
#		
#	return x_axis, data

def make_top_user_graph(top_users_to_graph):
	ips = [ip for ip, bytes in get_top_24h_ips(top_users_to_graph)]
	data = []
	times = [t for t in get_times()]
	for i in range(0, len(ips)):
		data.append([])

	x_axis = []
	for time in times:
		x_axis.append(time)
		x_axis.append(time+period)

		total = 0
		for idx, ip in enumerate(ips):
			bytes = get_ip_bandwidth(ip, time)
			speed = bytes / period
			total += speed
			data[idx].append(total)

	for idx in range(0, len(data)):
		data[idx] = repeat_once(data[idx])

	return x_axis, data

from datetime import datetime
def make_graph(x_axis, data, color_vertically=True):
	x_axis = x_axis[:]
	data = data[:]

	max_y_value = 24500000
	max_y = 24500000
	min_time = min(x_axis)
	max_time = max(x_axis)

	chart = XYLineChart(700, 400, x_range=[min_time, max_time], y_range=[0, max_y_value])

	chart.set_axis_labels(Axis.LEFT, ['', max_y_value])

	start_time = datetime.fromtimestamp(min(x_axis)).strftime("%H:%M")
	end_time = datetime.fromtimestamp(max(x_axis)).strftime("%H:%M")
	chart.set_axis_labels(Axis.BOTTOM, [start_time, end_time])

	# First value is the highest Y value. Two of them are needed to be
	# plottable.
	chart.add_data([min_time, max_time])
	chart.add_data([max_y] * 2)

	#print max_y, min_time, max_time
	prev_y = [0] * 2
	for bar in data[::-1]:
		Y = bar
		if not Y:
			Y = prev_y
		#print "X", idx, X
		#print "Y", idx, Y
		chart.add_data(x_axis)
		chart.add_data(Y)
		prev_y = Y

	chart.add_data([min_time, max_time])
	chart.add_data([0] * 2)

	# Black lines
	chart.set_colours(['000000'] * 5)

	color_chart_vertically(chart, data)

	print chart.get_url()
	return chart

def color_chart_vertically(chart, data):
	chart.add_fill_range("000000", 0, 1)
	colors = len(data)
	for i in range(0, colors):
		if colors == 1:
			brightness = 1
		else:
			brightness = i / float(colors-1)
		brightness = int(brightness * 0xFF)
		color = ("%02x%02x%02x" % (brightness, 0xFF-brightness, 0xFF-brightness))
		chart.add_fill_range(color, i+1, i+2)
def download(chart, filename):
	import urllib2
	bits = chart.get_url_bits()
	form = "&".join(bits)

        opener = urllib2.urlopen("http://chart.apis.google.com/chart", form)

        if opener.headers['content-type'] != 'image/png':
            raise BadContentTypeException('Server responded with a ' \
                'content-type of %s' % opener.headers['content-type'])

        open(filename, 'wb').write(opener.read())

#download(make_bandwidth_graph(), "basic_graph.png")
chart = make_category_graph()
download(chart, "category_graph.png")
download(make_graph(*make_top_user_graph(20)), "graph_top_user.png")

category_legend = []
for idx, color, name in category_types:
	category_legend.append("<span style='color: #%s'>%s</span>" % (color, name))
category_legend = "\n".join(category_legend)
subs = { "category_legend": category_legend }

with open("index.html", "w+") as index:
	index.write("""
<html><body>
All bandwidth usage by category:<br>
<img src='category_graph.png'>
<br>
%(category_legend)s
<p>Bandwidth usage of top 20 users over time:<br>
<img src='graph_top_user.png'>

</body></html>
""" % subs)


