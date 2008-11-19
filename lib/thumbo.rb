
require 'thumbo/proxy'

module Thumbo
  def self.included model
    model.__send__ :extend, Thumbo::ClassMethod
  end

  def self.calculate_dimension limit, width, height
    long, short = width >= height ? [width, height] : [height, width]

    if long <= limit # stay on
      [width, height]

    elsif width == height # square
      [limit, limit]

    else # detect which is longer

      # assume width is longer
      new_width, new_height = limit, short * (limit.to_f / long)

      # swap if height is longer
      new_width, new_height = new_height, new_width if long == height

      [new_width, new_height]
    end
  end

  module ClassMethod
    def thumbnails
      # could we avoid class variable?
      @@thumbo_thumbnails ||= {}
    end

    def thumbnails_square
      # could we avoid class variable?
      @@thumbo_thumbnails_square ||= {}
    end
  end

  def thumbnails
    @thumbnails ||= init_thumbnails
  end

  # same as thumbnail.filename, for writing
  def thumbnail_filename thumbnail
    "#{object_id}_#{thumbnail.label}.#{thumbnail.fileext}"
  end

  # same as thumbnail.fileuri, for fetching
  def thumbnail_uri_file thumbnail
    thumbnail_filename thumbnail
  end

  def thumbnail_mime_type
    thumbnails[:original].mime_type
  end

  def create_thumbnails after_scale = lambda{}
    # scale thumbnails
    self.class.thumbnails.merge(self.class.thumbnails_square).each_key{ |label|
      after_scale[ thumbnails[label].create ]
    }

    # the last one don't scale at all, but call hook too
    after_scale[ thumbnails[:original] ]

    self
  end

  private
  def init_thumbnails
    self.class.const_get('ThumbnailsNameTable').inject({}){ |thumbnails, name|
      label = name.first
      thumbnails[label] = Thumbo::Proxy.new self, label
      thumbnails
    }
  end

end # of Thumbs
