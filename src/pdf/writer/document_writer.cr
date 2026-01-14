module PDF
  module Writer
    # Writes a complete PDF document to an IO.
    #
    # The writer handles:
    # - PDF header and version
    # - Binary marker (for proper binary handling)
    # - All indirect objects
    # - Cross-reference table
    # - Trailer dictionary
    # - EOF marker
    class DocumentWriter
      # The document being written
      getter document : Document

      # Object byte offsets for xref table
      @offsets : Hash(Int32, Int64)

      def initialize(@document : Document)
        @offsets = {} of Int32 => Int64
      end

      # Writes the complete PDF to the given IO.
      def write(io : IO) : Nil
        # Finalize the document (creates all objects)
        @document.finalize!

        # Track current position
        position = 0_i64

        # Write header
        header = write_header
        io << header
        position += header.bytesize

        # Write all objects
        @document.objects.each do |obj|
          @offsets[obj.object_number] = position
          content = obj.to_pdf + "\n"
          io << content
          position += content.bytesize
        end

        # Write xref table
        xref_start = position
        xref = write_xref
        io << xref
        position += xref.bytesize

        # Write trailer
        trailer = write_trailer(xref_start)
        io << trailer
      end

      private def write_header : String
        # PDF header with version
        # Second line contains high-bit bytes to mark as binary
        "%PDF-#{PDF::PDF_VERSION}\n%\xE2\xE3\xCF\xD3\n"
      end

      private def write_xref : String
        String.build do |io|
          io << "xref\n"

          # We include object 0 (free entry) plus all our objects
          total_objects = @document.objects.size + 1
          io << "0 #{total_objects}\n"

          # Object 0 is always free with generation 65535
          io << "0000000000 65535 f \n"

          # Write entry for each object in order
          (1...total_objects).each do |obj_num|
            offset = @offsets[obj_num]? || 0_i64
            io << offset.to_s.rjust(10, '0')
            io << " 00000 n \n"
          end
        end
      end

      private def write_trailer(xref_start : Int64) : String
        String.build do |io|
          io << "trailer\n"
          io << "<<"
          io << "/Size #{@document.objects.size + 1}"
          io << "/Root #{@document.catalog.reference.to_pdf}"

          # Add info dictionary if present
          if info = @document.info_dict
            info_obj = @document.register_object(info)
            io << "/Info #{info_obj.reference.to_pdf}"
          end

          io << ">>\n"
          io << "startxref\n"
          io << xref_start
          io << "\n%%EOF\n"
        end
      end
    end
  end
end
