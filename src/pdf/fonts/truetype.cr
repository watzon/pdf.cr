# TrueType/OpenType font parsing and subsetting module
module PDF
  module Fonts
    module TrueType
    end
  end
end

# IO Helpers for binary reading/writing
require "./truetype/io_helpers"

# Table record structure
require "./truetype/table_record"

# Individual table parsers
require "./truetype/tables/head"
require "./truetype/tables/hhea"
require "./truetype/tables/maxp"
require "./truetype/tables/hmtx"
require "./truetype/tables/cmap"
require "./truetype/tables/loca"
require "./truetype/tables/glyf"
require "./truetype/tables/name"
require "./truetype/tables/post"
require "./truetype/tables/os2"

# Main parser and subsetter
require "./truetype/parser"
require "./truetype/subsetter"
