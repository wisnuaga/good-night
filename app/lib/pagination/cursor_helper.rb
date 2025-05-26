module Pagination
  module CursorHelper
    module_function

    def encode_cursor(id)
      Base64.urlsafe_encode64(id.to_s)
    end

    def decode_cursor(cursor)
      Base64.urlsafe_decode64(cursor).to_i
    rescue
      nil
    end
  end
end
