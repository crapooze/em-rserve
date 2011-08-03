
module EM::Rserve
  ID = Struct.new(:string) do
    def ignorable?
      string == '----' or string == "\r\n\r\n"
    end

    def last_one?
      string == "--\r\n"
    end
  end
end
