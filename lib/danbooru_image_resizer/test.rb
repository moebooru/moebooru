#!/usr/local/bin/ruby
require './danbooru_image_resizer.so'
[95,96,97,98].each { |n|
	Danbooru.resize_image("png", "test.png", "test-out-#{n}.jpg", 2490, 3500,
			      0, 0, 0, 0, n)
}

