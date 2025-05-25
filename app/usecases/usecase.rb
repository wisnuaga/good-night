require "ostruct"

class Usecase

  private

  def success(record)
    OpenStruct.new(success?: true, data: record)
  end

  def failure(error_message)
    OpenStruct.new(success?: false, error: error_message)
  end
end