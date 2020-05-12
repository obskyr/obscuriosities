module Jekyll
  class Octopod
    module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 9
      TINY  = 23
      TAG   = "obskyr"

      STRING = [MAJOR, MINOR, TINY].join('.') + (TAG ? "-" + TAG : "")
    end
  end
end
