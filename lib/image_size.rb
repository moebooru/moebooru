# encoding: ascii-8bit
require 'stringio'
require 'tempfile'

class ImageSize
  class Size < Array
    # join using 'x'
    def to_s
      join('x')
    end
  end

  class ImageReader # :nodoc:
    def initialize(data_or_io)
      @io = case data_or_io
      when IO, StringIO, Tempfile
        data_or_io.dup.tap(&:rewind)
      when String
        StringIO.new(data_or_io)
      else
        raise ArgumentError.new("expected instance of IO, StringIO, Tempfile or String, got #{data_or_io.class}")
      end
      @read = 0
      @data = ''
    end

    def rewind
      @io.rewind
    end

    CHUNK = 1024
    def [](offset, length)
      while offset + length > @read
        @read += CHUNK
        if data = @io.read(CHUNK)
          @data << data
        end
      end
      @data[offset, length]
    end
  end

  # Given path to image finds its format, width and height
  def self.path(path)
    open(path, 'rb'){ |f| new(f) }
  end

  # Given image as IO, StringIO, Tempfile or String finds its format and dimensions
  def initialize(data)
    ir = ImageReader.new(data)
    if @format = detect_format(ir)
      @width, @height = self.send("size_of_#{@format}", ir)
    end
    ir.rewind
  end

  # Image format
  attr_reader :format

  # Image width
  attr_reader :width
  alias :w :width

  # Image height
  attr_reader :height
  alias :h :height

  # get image width and height as an array which to_s method returns "#{width}x#{height}"
  def size
    if format
      Size.new([width, height])
    end
  end

private

  def detect_format(ir)
    head = ir[0, 1024]
    case
    when head =~ /^GIF8[7,9]a/              then :gif
    when head[0, 8] == "\211PNG\r\n\032\n"  then :png
    when head[0, 2] == "\377\330"           then :jpeg
    when head[0, 2] == 'BM'                 then :bmp
    when head =~ /^P[1-7]/                  then :ppm
    when head =~ /\#define\s+\S+\s+\d+/     then :xbm
    when head[0, 4] == "II*\000"            then :tiff
    when head[0, 4] == "MM\000*"            then :tiff
    when head =~ /\/\* XPM \*\//            then :xpm
    when head[0, 4] == '8BPS'               then :psd
    when head =~ /^[FC]WS/                  then :swf
    when head[0, 1] == "\n"                 then :pcx
    end
  end

  def size_of_gif(ir)
    ir[6, 4].unpack('vv')
  end

  def size_of_png(ir)
    unless ir[12, 4] == 'IHDR'
      raise 'IHDR not in place for PNG'
    end
    ir[16, 8].unpack('NN')
  end

  JpegCodeCheck = [
    "\xc0", "\xc1", "\xc2", "\xc3",
    "\xc5", "\xc6", "\xc7",
    "\xc9", "\xca", "\xcb",
    "\xcd", "\xce", "\xcf",
  ] # :nodoc:
  def size_of_jpeg(ir)
    section_marker = "\xFF"
    offset = 2
    loop do
      marker, code, length = ir[offset, 4].unpack('aan')
      offset += 4
      raise 'JPEG marker not found' if marker != section_marker

      if JpegCodeCheck.include?(code)
        return ir[offset + 1, 4].unpack('nn').reverse
      end
      offset += length - 2
    end
  end

  def size_of_bmp(ir)
    ir[18, 8].unpack('VV')
  end

  def size_of_ppm(ir)
    header = ir[0, 1024]
    header.gsub!(/^\#[^\n\r]*/m, '')
    header =~ /^(P[1-6])\s+?(\d+)\s+?(\d+)/m
    case $1
      when 'P1', 'P4' then @format = :pbm
      when 'P2', 'P5' then @format = :pgm
    end
    [$2.to_i, $3.to_i]
  end

  def size_of_xbm(ir)
    ir[0, 1024] =~ /^\#define\s*\S*\s*(\d+)\s*\n\#define\s*\S*\s*(\d+)/mi
    [$1.to_i, $2.to_i]
  end

  def size_of_xpm(ir)
    length = 1024
    until (data = ir[0, length]) =~ /"\s*(\d+)\s+(\d+)(\s+\d+\s+\d+){1,2}\s*"/m
      if data.length != length
        raise 'XPM size not found'
      end
      length += 1024
    end
    [$1.to_i, $2.to_i]
  end

  def size_of_psd(ir)
    ir[14, 8].unpack('NN')
  end

  def size_of_tiff(ir)
    endian2b = (ir[0, 4] == "II*\000") ? 'v' : 'n'
    endian4b = endian2b.upcase
    packspec = [nil, 'C', nil, endian2b, endian4b, nil, 'c', nil, endian2b, endian4b]

    offset = ir[4, 4].unpack(endian4b)[0]
    num_dirent = ir[offset, 2].unpack(endian2b)[0]
    offset += 2
    num_dirent = offset + (num_dirent * 12)

    width = height = nil
    until width && height
      ifd = ir[offset, 12]
      raise 'Reached end of directory entries in TIFF' if ifd.nil? || offset > num_dirent
      tag, type = ifd.unpack(endian2b * 2)
      offset += 12

      unless packspec[type].nil?
        value = ifd[8, 4].unpack(packspec[type])[0]
        case tag
        when 0x0100
          width = value
        when 0x0101
          height = value
        end
      end
    end
    [width, height]
  end

  def size_of_pcx(ir)
    parts = ir[4, 8].unpack('S4')
    [parts[2] - parts[0] + 1, parts[3] - parts[1] + 1]
  end

  def size_of_swf(ir)
    value_bit_length = ir[8, 1].unpack('B5').first.to_i(2)
    bit_length = 5 + value_bit_length * 4
    rect_bits = ir[8, bit_length / 8 + 1].unpack("B#{bit_length}").first
    values = rect_bits.unpack('@5' + "a#{value_bit_length}" * 4).map{ |bits| bits.to_i(2) }
    x_min, x_max, y_min, y_max = values
    [(x_max - x_min) / 20, (y_max - y_min) / 20]
  end
end
