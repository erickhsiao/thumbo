
require 'RMagick'

module Thumbo
  class Proxy
    attr_reader :title
    def initialize owner, title
      @owner, @title = owner, title
      @image = nil # please stop warning me @image is not defined
    end

    # image processing
    def image
      @image || (self.image = read_image)
    end

    # check if image exists in memory
    def image?
      @image
    end

    def image_with_timeout time_limit = 5
      @image || (self.image = read_image_with_timeout(time_limit))
    end

    def image= new_image
      release
      @image = new_image
    end

    # is this helpful or not?
    def release(*o)
      #begin
      #  self.destroy!
      #rescue Exception=>e
#	puts "Error Release with #{e}"
 #     end
      @image = nil
      GC.start
      #owner.destroy_and_update_checksum(owner,o[0]) if o.length>0
      self
    end

    # e.g.,
    # thumbnails[:original].from_blob uploaded_file.read
    def from_blob blob, &block
      self.image = Magick::ImageList.new.from_blob(blob, &block)
      self
    end

    def to_blob &block
      self.image.to_blob(&block)
    end

    # convert format to website displable image format
    def convert_format_for_website
      image.format = 'PNG' unless ['GIF', 'JPEG'].include?(image.format)
    end

    # create thumbnails in the image list (Magick::ImageList)
    def create(*custom_width)
      return if title == :original
      release
      cw=(custom_width && custom_width.length>0) ? custom_width[0] : 0
      limit=cw>0 ? cw : owner.class.thumbo_common[title]
      begin
	#owner.remove_labels_files(owner.id,Photo.thumbo_labels[title]) if title!=:original
      rescue Exception=>e
	puts e
      end
      if title.to_s.match(/square/)
        create_square(limit)

      else
        create_common(limit)

      end
      puts "c5"
      self
    end

    def write filename = nil, &block
      storage.write(filename || self.filename, to_blob(&block))
    end

    # delegate all
    def method_missing msg, *args, &block
      raise 'fetch image first if you want to operate the image' unless @image

      if image.__respond_to__?(msg) # operate ImageList, a dirty way because of RMagick...
         [image.__send__(msg, *args, &block)]

      elsif image.first.respond_to?(msg) # operate each Image in ImageList
        image.to_a.map{ |layer| layer.__send__(msg, *args, &block) }

      else # no such method...
        super(msg, *args, &block)

      end
    end

    # storage related
    def storage
      owner.class.thumbo_storage
    end

    def paths
      storage.paths(filename)
    end

    def delete
      storage.delete(filename)
    end

    # owner delegate
    def filename
      puts "FileName ==>>>>#{owner.thumbo_filename} #{self}"
      owner.thumbo_filename self
    end

    def uri
      owner.thumbo_uri self
    end

    # attribute
    def dimension img = image.first
      [img.columns, img.rows]
    end

    def mime_type
      image.first.mime_type
    end

    def fileext
      if @image
        case ext = image.first.format
          when 'PNG8';   'png'
          when 'PNG24';  'png'
          when 'PNG32';  'png'
          when 'GIF87';  'gif'
          when 'JPEG';   'jpg'
          when 'PJPEG';  'jpg'
          when 'BMP2';   'bmp'
          when 'BMP3';   'bmp'
          when 'TIFF64'; 'tiff'
          else; ext.downcase
        end

      elsif owner.respond_to?(:thumbo_default_fileext)
        owner.thumbo_default_fileext

      else
        raise "please implement #{owner.class}\#thumbo_default_fileext or Thumbo can't guess the file extension"

      end
    end

    #protected
    attr_reader :owner
    protected
    def create_common limit
      # can't use map since it have different meaning to collect here
      type= owner.rotate_cal.to_s=="0" ? "raw".to_sym : "original".to_sym
      puts("Using type #{type}  #{owner.id}")
      img=""
      img=Photo.thumbo_storage.read("#{owner.id}_#{type.to_s}.#{handle_ext(owner.content_type)}")
      self.image = owner.thumbos[type].image.collect{ |layer|
	#img=layer
	puts "cc2 limit?#{limit} self?#{self}"
        # i hate column and row!! nerver remember which is width...
        new_dimension = Thumbo.calculate_dimension(limit, layer.columns, layer.rows)
        # no need to scale
        if new_dimension == dimension(layer)
          layer

        # scale to new_dimension
        else
          layer.scale(*new_dimension)

        end
	
        #puts "cc-done"
      }
      puts ""
      begin
         puts("~~~~~thumbo~Trying to save file of image in memory. #{owner.id}")
         Dir.chdir("/home/photo/tmp/images/")
         ans = StringIO.new(img)
         ans=write(img)
         file=File.new("from_thumbo_#{self.id}_raw." +handle_ext(self.content_type)+"?#{Time.now.strftime('%Y%m%d%H%M%S')}","w+")
         file.write(ans.string)
         file.close
      rescue Exception => e
         puts("~~~~~~Test Error #{e}")
      end
      puts ""

      self.image
    end

    def create_square limit
      type= owner.rotate_cal.to_s=="0" ? "raw".to_sym : "original".to_sym
      puts("Using type #{type}  #{owner.id}")
      img=""
      img=Photo.thumbo_storage.read("#{owner.id}_#{type.to_s}.#{handle_ext(owner.content_type)}")
      self.image = owner.thumbos[type].image.collect{ |layer|
        layer.crop_resized(limit, limit).enhance
      }

      puts ""
      begin
        puts("~~~~~tumbo square~Trying to save file of image in memory.  #{owner.id}")
        Dir.chdir("/home/photo/tmp/images/")
        ans = StringIO.new(img)
        ans=write(img)
        file=File.new("from_thumbo_#{self.id}_raw." +handle_ext(self.content_type)+"?#{Time.now.strftime('%Y%m%d%H%M%S')}","w+")
        file.write(ans.string)
        file.close
      rescue Exception => e
        puts("~~~~~~Test Error #{e}")
      end
      puts ""

      self.image
    end
    def handle_ext (ext)
       return ext.split('/')[1].gsub('jpeg','jpg').gsub('JPEG','JPG')
    end
    private
    # fetch image from storage to memory
    # raises Magick::ImageMagickError
    def read_image
      Magick::ImageList.new.from_blob(storage.read(filename))
    end

    def read_image_with_timeout time_limit = 5
      Timeout.timeout(time_limit){ fetch }
    end
  end
end
