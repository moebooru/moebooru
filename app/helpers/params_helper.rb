module ParamsHelper
  def parse_date(input)
    return input if input.is_a? Date

    return unless input.is_a? String

    begin
      # Date.parse has max length requirement of 128 characters
      Date.parse(input[...128])
    rescue Date::Error => e
      # just return nil
    end
  end

  def parse_int(input)
    return input if input.is_a? Integer

    return unless input.is_a?(String) && input.present?

    # TODO: decide if want to only accept number-like string
    input.to_i
  end

  def parse_str(input)
    return input if input.is_a? String
  end
end
