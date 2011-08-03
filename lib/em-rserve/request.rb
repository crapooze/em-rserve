
#XXX
# - todo: implement these requests
module EM::Rserve
  class Request
    include EM::Rserve::QAP1

    class << self
      attr_accessor :has_body_flag

      alias :body :has_body_flag=

        def body?
          @has_body_flag && true
        end

      def code(val=nil)
        if val
          @code = val
        end
        @code
      end
    end

    class Login < Request
      code CMD_login
      body :string
    end

    class Shutdown < Request
      code CMD_shutdown
      body false #or :string
    end

    class VoidEval < Request
      code CMD_voidEval
      body :string
    end

    class Eval < Request
      code CMD_eval
      body :sexp
    end
  end
end
